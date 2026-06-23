/**
 * Builds a release APK and copies it to dist/spendlog.apk for GitHub release upload.
 * Bakes API_BASE_URL and GOOGLE_SERVER_CLIENT_ID from .env via --dart-define.
 */
const { execSync } = require("child_process");
const fs = require("fs");
const path = require("path");
const { readProjectEnv } = require("./read-env.cjs");

const root = path.join(__dirname, "..");
const apkOut = path.join(
  root,
  "build",
  "app",
  "outputs",
  "flutter-apk",
  "app-release.apk",
);
const distDir = path.join(root, "dist");
const releaseApk = path.join(distDir, "spendlog.apk");

const env = readProjectEnv(root);
const apiBaseUrl = env.API_BASE_URL?.trim();
if (!apiBaseUrl) {
  console.error("build-apk: API_BASE_URL missing in .env");
  process.exit(1);
}

if (apiBaseUrl.startsWith("http://")) {
  console.warn(
    "WARNING: Release build uses HTTP. Android blocks cleartext except localhost.",
  );
  console.warn("Use HTTPS (e.g. https://spendlogweb.netlify.app/api/v1) for production APKs.");
}

const defines = [`API_BASE_URL=${apiBaseUrl}`];
const googleClientId = env.GOOGLE_SERVER_CLIENT_ID?.trim();
if (googleClientId) {
  defines.push(`GOOGLE_SERVER_CLIENT_ID=${googleClientId}`);
}

const defineArgs = defines
  .map((d) => `--dart-define=${d}`)
  .join(" ");

console.log(`Building release APK (API_BASE_URL=${apiBaseUrl})…`);
execSync(`flutter build apk --release ${defineArgs}`, {
  cwd: root,
  stdio: "inherit",
  shell: true,
});

if (!fs.existsSync(apkOut)) {
  console.error(`APK not found at ${apkOut}`);
  process.exit(1);
}

fs.mkdirSync(distDir, { recursive: true });
fs.copyFileSync(apkOut, releaseApk);
console.log(`Release APK → ${releaseApk}`);
