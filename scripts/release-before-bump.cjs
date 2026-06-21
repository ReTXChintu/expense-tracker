/**
 * Saves the current Android build number (+N) before release-it bumps semver in pubspec.yaml.
 */
const fs = require("fs");
const path = require("path");

const pubspecPath = path.join(__dirname, "..", "pubspec.yaml");
const pubspec = fs.readFileSync(pubspecPath, "utf8");
const match = pubspec.match(/^version:\s*\d+\.\d+\.\d+(?:\+(\d+))?/m);
const build = match?.[1] ? parseInt(match[1], 10) : 0;

fs.writeFileSync(path.join(__dirname, "..", ".release-build"), String(build));
