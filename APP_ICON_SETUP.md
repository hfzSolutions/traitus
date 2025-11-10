# App Icon Setup Guide

This guide explains how to add and update the app icon for your Traitus AI Chat application across all platforms (iOS, Android, Web, macOS, Windows, and Linux).

## 📋 Overview

The project uses [`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons) to automatically generate all required icon sizes for each platform from a single source image. This eliminates the need to manually create multiple icon sizes for different platforms and screen densities.

## 🎨 Preparing Your Icon

### Requirements

1. **Format**: PNG image
2. **Size**: 1024x1024 pixels (recommended)
3. **Shape**: Square (the tool will handle rounding/corners per platform)
4. **Background**: Transparent or solid color (your choice)

### Design Tips

- Keep important content within the center 80% of the image (platforms may crop edges)
- Use high contrast colors for better visibility at small sizes
- Test your icon at different sizes to ensure it's recognizable
- Avoid text unless it's very large and simple

## 📁 Setup Steps

### 1. Place Your Icon Files

You'll need two icon files:

1. **App Launcher Icon** (`icon.png`):
   - 1024x1024 PNG with background color
   - Used for app launcher icons on all platforms
   - Place at: `assets/icon.png`

2. **Splash Screen Logo** (`logo.png`):
   - 1024x1024 PNG with transparent background (recommended)
   - Used for splash/loading screen and UI elements
   - Works well on both light and dark backgrounds
   - Place at: `assets/logo.png`

Your assets folder should look like:
```
assets/
├── icon.png  (app launcher icon - with background)
└── logo.png  (splash screen logo - transparent)
```

### 2. Configuration

The icon configuration is already set up in `pubspec.yaml`. Make sure both assets are listed:

```yaml
flutter:
  assets:
    - .env
    - assets/icon.png
    - assets/logo.png
```

The launcher icon configuration:

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  macos:
    generate: true
    image_path: "assets/icon.png"
  windows:
    generate: true
    image_path: "assets/icon.png"
  linux:
    generate: true
    image_path: "assets/icon.png"
  image_path: "assets/icon.png"
  min_sdk_android: 21
  web:
    generate: true
    image_path: "assets/icon.png"
    background_color: "#ffffff"
    theme_color: "#ffffff"
```

### 3. Generate Icons

Run the following command to generate all platform icons:

```bash
flutter pub get
dart run flutter_launcher_icons
```

This will:
- ✅ Generate Android icons for all density folders (mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi)
- ✅ Generate iOS icons for all required sizes (20pt, 29pt, 40pt, 60pt, 76pt, 83.5pt, 1024pt)
- ✅ Generate macOS icons (16pt, 32pt, 128pt, 256pt, 512pt, 1024pt)
- ✅ Generate Windows icons
- ✅ Generate Linux icons
- ✅ Generate Web icons (192px, 512px, maskable variants)

### 4. Verify Icons

After generation, you can verify the icons were created:

- **Android**: Check `android/app/src/main/res/mipmap-*/ic_launcher.png`
- **iOS**: Check `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- **macOS**: Check `macos/Runner/Assets.xcassets/AppIcon.appiconset/`
- **Web**: Check `web/icons/`
- **Windows**: Check `windows/runner/` for `.ico` files
- **Linux**: Check `linux/` for icon files

## 🔄 Updating Your Icon

To update your app icon:

1. Replace the `assets/icon.png` file with your new icon
2. Run `dart run flutter_launcher_icons` again
3. Rebuild your app to see the changes

### ⚠️ Important: Asset Caching

If you replace an asset file (like `icon.png` or `logo.png`) with the same filename, Flutter may cache the old version. To see your changes:

1. **Clean the build cache**:
   ```bash
   flutter clean
   flutter pub get
   ```

2. **Full app restart** (not just hot reload):
   - Stop the app completely
   - Run `flutter run` again
   - Or uninstall and reinstall the app on your device/emulator

3. **For splash screen logo** (`assets/logo.png`):
   - After replacing the file, run `flutter clean` and restart the app
   - Hot reload won't pick up asset changes - you need a full restart

**Note**: This applies to any asset file you replace - images, fonts, etc. Always do a full restart after replacing assets.

## 🎨 Customizing Web Icons

The web icons include background and theme colors. To customize them, edit the `web` section in `pubspec.yaml`:

```yaml
web:
  generate: true
  image_path: "assets/icon.png"
  background_color: "#ffffff"  # Change to your preferred background color
  theme_color: "#ffffff"        # Change to your preferred theme color
```

After changing these values, run `dart run flutter_launcher_icons` again.

## 🚀 Applying Icons to Your App

After generating icons, you need to rebuild your app to see them:

### iOS
```bash
flutter build ios
# Or run from Xcode
```

### Android
```bash
flutter build apk
# Or run from Android Studio
```

### Web
```bash
flutter build web
```

### macOS
```bash
flutter build macos
```

### Windows
```bash
flutter build windows
```

### Linux
```bash
flutter build linux
```

**Note**: For iOS and macOS, you may need to clean the build folder first:
```bash
flutter clean
flutter pub get
```

## 🐛 Troubleshooting

### Icons Not Appearing After Generation

1. **Clean and rebuild**:
   ```bash
   flutter clean
   flutter pub get
   dart run flutter_launcher_icons
   flutter run
   ```

2. **Check file path**: Ensure `assets/icon.png` exists and is the correct size

3. **Verify configuration**: Check that `pubspec.yaml` has the correct `image_path`

### Icon Generation Errors

- **Invalid image format**: Ensure your icon is a PNG file
- **File not found**: Verify `assets/icon.png` exists
- **Configuration errors**: Check YAML syntax in `pubspec.yaml`

### Platform-Specific Issues

#### iOS - App Launcher Icon Not Updating

iOS aggressively caches app icons. If your new icon doesn't appear after updating:

1. **Complete cleanup**:
   ```bash
   # Clean Flutter build
   flutter clean
   
   # Clean iOS build artifacts
   cd ios
   rm -rf build Pods Podfile.lock .symlinks
   cd ..
   
   # Clean Xcode derived data
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```

2. **Regenerate icons**:
   ```bash
   dart run flutter_launcher_icons
   flutter pub get
   ```

3. **Uninstall app from simulator/device**:
   - **Simulator**: Long-press app icon → Delete, or reset simulator (Device → Erase All Content and Settings)
   - **Physical device**: Delete the app completely

4. **Rebuild from scratch**:
   ```bash
   flutter run
   ```

5. **If still not working, build from Xcode**:
   - Open `ios/Runner.xcworkspace` in Xcode
   - Product → Clean Build Folder (Shift+Cmd+K)
   - Product → Run

**Note**: iOS app launcher icons are cached at the OS level. A full uninstall and rebuild is usually required.

#### iOS - Splash Screen Logo Not Updating

If `assets/logo.png` (splash screen) isn't updating:

1. **Clean and restart**:
   ```bash
   flutter clean
   flutter pub get
   ```

2. **Full app restart** (not hot reload):
   - Stop the app completely
   - Run `flutter run` again
   - Hot reload won't pick up asset changes

3. **Verify file exists**: Check that `assets/logo.png` is in the correct location

#### Android
- Uninstall the app completely before reinstalling
- Check that all mipmap folders have `ic_launcher.png` files
- Clear app data: Settings → Apps → Your App → Clear Data

#### Web
- Clear browser cache to see new favicon
- Check `web/manifest.json` references the correct icon paths
- Hard refresh: Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows/Linux)

## 📚 Additional Resources

- [flutter_launcher_icons Package](https://pub.dev/packages/flutter_launcher_icons)
- [Flutter App Icons Documentation](https://docs.flutter.dev/deployment/android#reviewing-the-app-manifest)
- [iOS App Icon Guidelines](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- [Android Icon Guidelines](https://developer.android.com/guide/practices/ui_guidelines/icon_design)

## ✅ Checklist

- [ ] App launcher icon (`icon.png`) is 1024x1024 PNG with background
- [ ] Splash screen logo (`logo.png`) is 1024x1024 PNG with transparent background
- [ ] Both files are placed in `assets/` directory
- [ ] Both assets are listed in `pubspec.yaml` under `flutter: assets:`
- [ ] `flutter pub get` has been run
- [ ] `dart run flutter_launcher_icons` completed successfully
- [ ] App has been rebuilt after icon generation
- [ ] App launcher icons appear correctly on target platforms
- [ ] Splash screen logo appears correctly when app loads

---

**Last Updated**: Icon setup configured with flutter_launcher_icons v0.13.1

