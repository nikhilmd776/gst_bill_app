
### STEP 1: CREATE NEW CODESPACES

1. Go to: https://github.com/codespaces
2. Click **"New codespace"**
3. **Repository**: `New repository`
   - Name: `gst_bill_app` (use underscore!)
   - Public → **Create**
4. **Dev container configuration**: GitHub will automatically detect and use the "Flutter with Android SDK" configuration (it auto-sets up everything)
5. Click **"Create codespace"**

Wait 2 minutes → VS Code opens

---

### STEP 2: FULL AUTO SETUP (COPY-PASTE THIS BLOCK)

```bash
# === FULL AUTO: FLUTTER + GST APP ===
git clone https://github.com/flutter/flutter.git -b stable $HOME/flutter && \
export PATH="$PATH:$HOME/flutter/bin" && \
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc && \
source ~/.bashrc && \
flutter --version && \
flutter create . && \
cat > pubspec.yaml << 'EOF'
name: gst_bill_app
description: GST Bill Generator
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  pdf: ^3.11.1
  printing: ^5.13.0
  path_provider: ^2.1.4
  share_plus: ^10.0.0
  shared_preferences: ^2.3.0
  intl: ^0.19.0

flutter:
  uses-material-design: true
EOF

flutter pub get && \
flutter config --enable-web && \
flutter precache --web
```

**Wait 4 minutes**


### STEP 3: TEST IN WEB

```bash
flutter run -d web-server --web-port 4000
```

**OPEN `http://localhost:4000` IN BROWSER** → **TEST LIVE!**

---

### STEP 4: BUILD APK (Everything is Pre-Configured)

```bash
# === SIMPLE APK BUILD (SDK already installed) ===
flutter build apk --release
```

**Wait 1 minute** → **APK READY**

---

### STEP 5: DOWNLOAD APK

1. Left panel → `build` → `app` → `outputs` → `flutter-apk`
2. Right-click `app-release.apk` → **Download**

---

## DONE!

---

### STEP 6: BUILD & SERVE WEB (Static — recommended in containers) 🔧

To create a production web build and serve it locally (works well inside Codespaces/devcontainers):

1. Build the web output:
```bash
flutter build web
```

2. Serve the build folder on port 4000:
```bash
python3 -m http.server 4000 --directory build/web
```

3. Open in browser:
- Locally: http://127.0.0.1:4000
- Or use Codespaces forwarded URL: https://<workspace>-4000.app.github.dev

Notes:
- If you need live debugging/hot reload in Chrome but are inside a restricted container, Chrome may fail to launch due to sandboxing. As a quick workaround for local testing only, you can launch Chrome with no sandbox:
```bash
echo -e '#!/bin/bash\nexec /usr/bin/google-chrome --no-sandbox "$@"' > /tmp/chrome_no_sandbox.sh && chmod +x /tmp/chrome_no_sandbox.sh
CHROME_EXECUTABLE=/tmp/chrome_no_sandbox.sh flutter run -d chrome --web-hostname 0.0.0.0 --web-port 4000 -v
```
- For most container workflows, the static build + `http.server` is the most reliable method.

---

