/**
 * Parses a simple KEY=VALUE .env file (no multiline / quoted values).
 */
const fs = require("fs");
const path = require("path");

function readEnvFile(envPath) {
  const result = {};
  if (!fs.existsSync(envPath)) return result;

  for (const line of fs.readFileSync(envPath, "utf8").split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eq = trimmed.indexOf("=");
    if (eq === -1) continue;
    const key = trimmed.slice(0, eq).trim();
    const value = trimmed.slice(eq + 1).trim();
    if (key) result[key] = value;
  }
  return result;
}

function readProjectEnv(root = path.join(__dirname, "..")) {
  return readEnvFile(path.join(root, ".env"));
}

module.exports = { readEnvFile, readProjectEnv };
