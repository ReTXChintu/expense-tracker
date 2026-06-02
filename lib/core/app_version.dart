/// App version shown in Profile. Keep in sync with `version:` in pubspec.yaml.
const String kAppName = 'SpendLog';

/// Semantic version only (part before `+` in pubspec, e.g. `1.0.0+1` → `1.0.0`).
const String kAppVersion = '1.0.1';

String appVersionLabel({bool showName = true}) =>
    showName ? '$kAppName v$kAppVersion' : 'v$kAppVersion';
