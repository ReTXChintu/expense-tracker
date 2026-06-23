/**
 * Runs release-it with GITHUB_TOKEN from `gh auth token` or the environment.
 * Validates the token before release-it runs (avoids opaque auth errors).
 */
const { execSync, spawnSync } = require("child_process");
const path = require("path");

const root = path.join(__dirname, "..");
const ghShell = process.platform === "win32";

/** gh echoes $GITHUB_TOKEN when set — use keyring by unsetting it for the subprocess. */
function ghSubprocessEnv() {
  const env = { ...process.env };
  delete env.GITHUB_TOKEN;
  return env;
}

function githubToken() {
  try {
    const fromGh = execSync("gh auth token", {
      cwd: root,
      encoding: "utf8",
      shell: ghShell,
      env: ghSubprocessEnv(),
    }).trim();
    if (fromGh) return { token: fromGh, source: "gh keyring" };
  } catch {
    // gh not installed or not logged in
  }
  const fromEnv = process.env.GITHUB_TOKEN?.trim();
  if (fromEnv) return { token: fromEnv, source: "GITHUB_TOKEN" };
  return null;
}

async function validateGitHubToken(token) {
  const res = await fetch("https://api.github.com/user", {
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28",
      "User-Agent": "expense-tracker-release",
    },
  });
  if (!res.ok) {
    const body = await res.text().catch(() => "");
    return { ok: false, status: res.status, body };
  }
  const user = await res.json();
  return { ok: true, login: user.login };
}

async function main() {
  const resolved = githubToken();
  if (!resolved) {
    console.error(
      "ERROR: Could not authenticate with GitHub. Run `gh auth login` or set GITHUB_TOKEN (repo scope).",
    );
    process.exit(1);
  }

  const { token, source } = resolved;
  const check = await validateGitHubToken(token);
  if (!check.ok) {
    console.error(
      `ERROR: GitHub token from ${source} failed validation (HTTP ${check.status}).`,
    );
    console.error("Run `gh auth login -s repo` or create a new PAT with repo scope.");
    if (check.body) console.error(check.body.slice(0, 200));
    process.exit(1);
  }

  console.log(`GitHub auth OK (${check.login}, via ${source})`);

  const env = { ...process.env, GITHUB_TOKEN: token };
  const args = process.argv.slice(2);
  const releaseArgs = ["release-it", ...args];
  if (!args.includes("--ci") && !args.includes("--no-ci")) {
    releaseArgs.push("--ci");
  }

  const result = spawnSync("npx", releaseArgs, {
    cwd: root,
    env,
    stdio: "inherit",
    shell: true,
  });

  process.exit(result.status ?? 1);
}

main().catch((err) => {
  console.error("ERROR:", err.message || err);
  process.exit(1);
});
