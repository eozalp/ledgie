# Ledgie — Flutter Android App

A native Material You Android port of **Ledgie v13**, a hledger-compatible personal finance tracker.

## Features

- **Dashboard** — Net worth, monthly income/expenses, savings rate, top categories, 6-month overview
- **Ledger** — Searchable transaction list with date, description, accounts, amounts
- **Accounts** — Balance sheet by account type with hierarchy (assets, liabilities, income, expenses)
- **Charts** — Monthly bars, expense donut, trend lines, P&L waterfall, 30-day forecast
- **Smart Editor** — Form mode + raw hledger mode with account autocomplete
- **Import/Export** — `.hledger` file import, share, save to device, clipboard
- **Data** — `shared_preferences` for local storage, auto-backup (5 slots)
- **Full hledger parser** — date, flag, code, postings, inline comments, tags, commodities, balance assertions, aliases

## Build locally (5 minutes)

```bash
# 1. Install Flutter (if not installed)
#    https://docs.flutter.dev/get-started/install/linux

# 2. Clone / unzip this project
cd ledgie_flutter

# 3. Install dependencies
flutter pub get

# 4. Build debug APK (no signing needed)
flutter build apk --debug

# 5. Install on connected Android device
adb install build/app/outputs/flutter-apk/app-debug.apk

# — OR —
# 5b. Run directly
flutter run
```

## Build via GitHub Actions (auto APK)

1. Push this folder to a GitHub repo
2. Go to **Actions** tab → **Build APK** workflow
3. Click **Run workflow** → select `debug`
4. Download the APK artifact when the build finishes (~5 min)

### Signed release APK

1. Generate a keystore:
   ```bash
   keytool -genkey -v -keystore ledgie.jks -alias ledgie \
     -keyalg RSA -keysize 2048 -validity 10000
   ```
2. Add GitHub Secrets (`Settings → Secrets → Actions`):
   - `ANDROID_KEYSTORE_BASE64` → `base64 -w 0 ledgie.jks`
   - `ANDROID_KEYSTORE_PASSWORD`
   - `ANDROID_KEY_ALIAS` → `ledgie`
   - `ANDROID_KEY_PASSWORD`
3. Create a GitHub Release (tag `v1.0.0`) → the workflow auto-attaches the signed APK

## Project structure

```
lib/
  main.dart                    # App entry, Material You theme
  models/
    transaction.dart           # Transaction, Posting, ParseResult models
  services/
    parser.dart                # Full hledger plaintext parser (Dart port)
    ledger_service.dart        # Balances, dash stats, P&L, register, graph data
  providers/
    ledger_provider.dart       # State + persistence (ChangeNotifier)
  screens/
    home_screen.dart           # Bottom nav shell
    dashboard_screen.dart      # Overview with cards and charts
    transactions_screen.dart   # Searchable ledger list
    accounts_screen.dart       # COA with tabs and hierarchy
    charts_screen.dart         # fl_chart visualizations
    settings_screen.dart       # Import, export, raw editor, backup
    add_transaction_screen.dart # Smart form + raw hledger editor
    transaction_detail_screen.dart
  widgets/
    stat_card.dart
    mini_bar_chart.dart
.github/
  workflows/
    build_apk.yml             # CI/CD for debug + signed release APK
```

## Data format

Compatible with hledger plaintext accounting format:

```
2024-01-15 * Migros market
    expenses:food        450 TRY
    assets:bank:checking
```

Import any `.hledger` or `.journal` file. Export back at any time.

## Requirements

- Android 5.0+ (API 21+)
- Flutter 3.24+ / Dart 3.3+
- Java 17 (for building)
