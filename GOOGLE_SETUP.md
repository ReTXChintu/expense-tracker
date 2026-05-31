# Gmail / Google Sign-In setup (Android)

SpendLog reads bank transaction emails via the Gmail API. Android requires a **Google Cloud OAuth** setup. Without it, sign-in fails with `ApiException: 10` (developer error).

## 1. Google Cloud project

1. Open [Google Cloud Console](https://console.cloud.google.com/).
2. Create or select a project.
3. **APIs & Services → Library** → enable **Gmail API**.

## 2. OAuth consent screen

1. **APIs & Services → OAuth consent screen**.
2. Choose **External** (fine for personal use).
3. Add your Google account under **Test users** while the app is in **Testing**.
4. Add scope: `https://www.googleapis.com/auth/gmail.readonly` (or add it when creating credentials).

## 3. Create credentials

### Android OAuth client (fixes ApiException 10)

1. **APIs & Services → Credentials → Create credentials → OAuth client ID**.
2. Application type: **Android**.
3. Package name: `com.example.expense_tracker`
4. SHA-1 certificate fingerprint — get it from your machine:

```powershell
cd expense-tracker\android
.\gradlew.bat signingReport
```

Under **Variant: debug**, copy **SHA-1** (use this for `flutter run` debug builds).

If you ship a release build later, add another Android client with your **release** keystore SHA-1.

### Web OAuth client (required in app code)

1. **Create credentials → OAuth client ID → Web application**.
2. Copy the **Client ID** (ends with `.apps.googleusercontent.com`).
3. In the Flutter project, set `.env`:

```powershell
copy .env.example .env
```

```env
GOOGLE_SERVER_CLIENT_ID=123456789-xxxx.apps.googleusercontent.com
```

4. Hot restart or rebuild the app (`flutter run`).

## 4. Verify on device

1. Uninstall SpendLog from the phone (clears old sign-in state).
2. Run the app, open **Profile** or the Gmail banner → **Connect**.
3. Pick your Google account and approve Gmail access.

If it still fails, check `flutter run` logs for `[Gmail] signIn error:`.

## Troubleshooting

| Symptom | Fix |
|--------|-----|
| `ApiException: 10` | Wrong package name, missing SHA-1, or SHA-1 from a different keystore than the installed APK |
| Connect does nothing | `GOOGLE_SERVER_CLIENT_ID` empty in `.env` |
| Access blocked | Add your account as a **Test user** on the consent screen |
| Gmail connected, no email txs | Open the **day of the email** and tap **Refresh**; check logcat for `[Gmail] found N messages`. If N=0, mail may be on another date or in Promotions. If N>0 but parsed 0, forward a sample subject to improve parsers. |
| Same payment twice | SMS and Gmail rows are kept separately (purple SMS icon vs red mail icon) |

**Note:** If you connected Gmail **after** already opening a past day, reconnect Gmail once (or pull Refresh on that day) so email is scanned for that date.

## Configure in `.env`

```env
GOOGLE_SERVER_CLIENT_ID=123456789-xxxx.apps.googleusercontent.com
```

Copy from `.env.example` if you have not already:

```powershell
copy .env.example .env
```
