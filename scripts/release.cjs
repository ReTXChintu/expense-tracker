/**
 * Runs release-it with GITHUB_TOKEN from the environment or `gh auth token`.
 * Without a token, release-it falls back to the web UI and cannot upload APK assets.
 */
const { execSync, spawnSync } = require("child_process");
const path = require("path");

const root = path.join(__dirname, "..");

function githubToken() {
  try {
    const fromGh = execSync("gh auth token", { cwd: root, encoding: "utf8" }).trim();
    if (fromGh) return fromGh;
  } catch {
    // gh not installed or not logged in
  }
  const fromEnv = process.env.GITHUB_TOKEN?.trim();
  return fromEnv || null;
}

const token = githubToken();
const env = { ...process.env };
if (token) {
  env.GITHUB_TOKEN = token;
} else {
  console.error(
    "ERROR: Could not authenticate with GitHub. Run `gh auth login` or set GITHUB_TOKEN (repo scope).",
  );
  process.exit(1);
}

const args = process.argv.slice(2);
const result = spawnSync("npx", ["release-it", ...args], {
  cwd: root,
  env,
  stdio: "inherit",
  shell: true,
});

process.exit(result.status ?? 1);
