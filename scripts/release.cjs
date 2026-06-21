/**
 * Runs release-it with GITHUB_TOKEN from the environment or `gh auth token`.
 * Without a token, release-it falls back to the web UI and cannot upload APK assets.
 */
const { execSync, spawnSync } = require("child_process");
const path = require("path");

const root = path.join(__dirname, "..");

function githubToken() {
  if (process.env.GITHUB_TOKEN) return process.env.GITHUB_TOKEN;
  try {
    return execSync("gh auth token", { cwd: root, encoding: "utf8" }).trim();
  } catch {
    return null;
  }
}

const token = githubToken();
const env = { ...process.env };
if (token) {
  env.GITHUB_TOKEN = token;
} else {
  console.warn(
    "WARNING: No GITHUB_TOKEN and `gh auth token` failed. GitHub release assets will not upload.",
  );
  console.warn("Run `gh auth login` or set GITHUB_TOKEN, then retry.");
}

const args = process.argv.slice(2);
const result = spawnSync("npx", ["release-it", ...args], {
  cwd: root,
  env,
  stdio: "inherit",
  shell: true,
});

process.exit(result.status ?? 1);
