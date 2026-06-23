/**
 * Attaches dist/spendlog.apk to a GitHub release via the REST API.
 * Uses GITHUB_TOKEN or `gh auth token` when available.
 */
const { execSync } = require("child_process");
const fs = require("fs");
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

function githubRepo() {
  const url = execSync("git config --get remote.origin.url", {
    cwd: root,
    encoding: "utf8",
  }).trim();
  const match = url.match(/github\.com[:/]([^/]+)\/(.+?)(?:\.git)?$/i);
  if (!match) throw new Error(`Could not parse GitHub repo from origin: ${url}`);
  return { owner: match[1], repo: match[2] };
}

async function githubRequest(token, url, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: {
      Accept: "application/vnd.github+json",
      Authorization: `Bearer ${token}`,
      "X-GitHub-Api-Version": "2022-11-28",
      ...options.headers,
    },
  });
  if (!response.ok) {
    const body = await response.text();
    throw new Error(`${response.status} ${response.statusText}: ${body}`);
  }
  if (response.status === 204) return null;
  return response.json();
}

async function getReleaseByTag(token, owner, repo, tag) {
  try {
    return await githubRequest(
      token,
      `https://api.github.com/repos/${owner}/${repo}/releases/tags/${tag}`,
    );
  } catch (err) {
    if (String(err.message).startsWith("404")) return null;
    throw err;
  }
}

async function createRelease(token, owner, repo, tag, version) {
  return githubRequest(
    token,
    `https://api.github.com/repos/${owner}/${repo}/releases`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        tag_name: tag,
        name: tag,
        generate_release_notes: true,
      }),
    },
  );
}

async function deleteAsset(token, owner, repo, assetId) {
  await githubRequest(
    token,
    `https://api.github.com/repos/${owner}/${repo}/releases/assets/${assetId}`,
    { method: "DELETE" },
  );
}

async function uploadAsset(token, uploadUrl, filePath, label) {
  const data = fs.readFileSync(filePath);
  const url = `${uploadUrl.split("{")[0]}?name=${encodeURIComponent(label)}`;
  const response = await fetch(url, {
    method: "POST",
    headers: {
      Accept: "application/vnd.github+json",
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/vnd.android.package-archive",
      "Content-Length": String(data.length),
      "X-GitHub-Api-Version": "2022-11-28",
    },
    body: data,
  });
  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Upload failed (${response.status}): ${body}`);
  }
  return response.json();
}

async function main() {
  const version = process.argv[2];
  if (!version) {
    console.error("upload-github-apk: missing version argument");
    process.exit(1);
  }

  const token = githubToken();
  if (!token) {
    console.error(
      "upload-github-apk: set GITHUB_TOKEN or run `gh auth login`",
    );
    process.exit(1);
  }

  const tag = `v${version}`;
  const apk = path.join(root, "dist", "spendlog.apk");
  if (!fs.existsSync(apk)) {
    console.error(`upload-github-apk: ${apk} not found`);
    process.exit(1);
  }

  const { owner, repo } = githubRepo();
  let release = await getReleaseByTag(token, owner, repo, tag);
  if (!release) {
    console.log(`Creating GitHub release ${tag}…`);
    release = await createRelease(token, owner, repo, tag, version);
  }

  const existing = (release.assets || []).find((a) => a.name === "spendlog.apk");
  if (existing) {
    console.log("Replacing existing spendlog.apk…");
    await deleteAsset(token, owner, repo, existing.id);
  }

  console.log(`Uploading spendlog.apk to ${tag}…`);
  const asset = await uploadAsset(
    token,
    release.upload_url,
    apk,
    "spendlog.apk",
  );
  console.log(`Attached: ${asset.browser_download_url}`);
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
