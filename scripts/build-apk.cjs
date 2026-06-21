/**
 * Builds a release APK and copies it to dist/spendlog.apk for GitHub release upload.
 */
const { execSync } = require("child_process");
const fs = require("fs");
const path = require("path");

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

console.log("Building release APK…");
execSync("flutter build apk --release", { cwd: root, stdio: "inherit" });

if (!fs.existsSync(apkOut)) {
  console.error(`APK not found at ${apkOut}`);
  process.exit(1);
}

fs.mkdirSync(distDir, { recursive: true });
fs.copyFileSync(apkOut, releaseApk);
console.log(`Release APK → ${releaseApk}`);
