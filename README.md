# SpendLog (expense_tracker)

Flutter app + NestJS backend for daily expense tracking with SMS and Gmail import.

## Gmail on Android

Gmail connect requires Google Cloud OAuth setup. See **[GOOGLE_SETUP.md](GOOGLE_SETUP.md)**.

Quick steps:

1. Enable **Gmail API** and configure **OAuth consent screen** in Google Cloud.
2. Create an **Android** OAuth client (`com.example.expense_tracker` + debug SHA-1).
3. Create a **Web** OAuth client and set `GOOGLE_SERVER_CLIENT_ID` in `.env`.
4. Rebuild the app and tap **Connect** on the Today screen or Profile.

```powershell
cd android
.\gradlew.bat signingReport
```

## Environment (`.env`)

```powershell
cd expense-tracker
copy .env.example .env
# Edit .env — API_BASE_URL, GOOGLE_SERVER_CLIENT_ID
```

| Variable | Description |
|----------|-------------|
| `API_BASE_URL` | Backend URL including prefix, e.g. `https://your-api.vercel.app/api/v1` |
| `GOOGLE_SERVER_CLIENT_ID` | Web OAuth client ID for Gmail |

`.env` is gitignored; commit only `.env.example`.

## Run

- Backend: `npm run start:dev` in `expense-tracker-backend`
- App: `flutter run` in `expense-tracker` (after `.env` is configured)

## Release

Uses [release-it](https://github.com/release-it/release-it). A release bumps semver in `pubspec.yaml`, increments the `+build` suffix, updates `CHANGELOG.md`, builds `dist/spendlog.apk`, commits, tags `vX.Y.Z`, pushes, and creates a GitHub Release with the APK attached.

**One-time setup:**

```powershell
cd expense-tracker
npm install
gh auth login    # or set GITHUB_TOKEN with repo scope
```

**Major / minor / patch:**

```powershell
npm run release:major   # or release:minor / release:patch
```

Requires a clean git working tree. To build the APK only: `npm run build:apk`.
