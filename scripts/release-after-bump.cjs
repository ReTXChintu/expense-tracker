/**
 * Appends an incremented Android build number after release-it bumps semver.
 * Example: 1.1.0+3 → 2.0.0+4 when releasing major 2.0.0.
 */
const fs = require("fs");
const path = require("path");

const semver = process.argv[2];
if (!semver) {
  console.error("release-after-bump: missing semver argument");
  process.exit(1);
}

const root = path.join(__dirname, "..");
const buildFile = path.join(root, ".release-build");
const pubspecPath = path.join(root, "pubspec.yaml");

const oldBuild = fs.existsSync(buildFile)
  ? parseInt(fs.readFileSync(buildFile, "utf8"), 10)
  : 0;
const newBuild = oldBuild + 1;

let pubspec = fs.readFileSync(pubspecPath, "utf8");
pubspec = pubspec.replace(/^version:.*/m, `version: ${semver}+${newBuild}`);
fs.writeFileSync(pubspecPath, pubspec);

if (fs.existsSync(buildFile)) fs.unlinkSync(buildFile);

console.log(`pubspec.yaml → ${semver}+${newBuild}`);
