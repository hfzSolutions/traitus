# Version & Build Number Management Guide

## Overview

This guide explains how to properly manage version and build numbers for the Traitus Flutter app, especially for TestFlight and App Store releases.

## Version Format

Flutter uses the following format in `pubspec.yaml`:

```yaml
version: MAJOR.MINOR.PATCH+BUILD
```

**Example:**
```yaml
version: 1.0.0+2
```

Where:
- **Version** (`1.0.0`): The user-facing version number (MAJOR.MINOR.PATCH)
- **Build Number** (`2`): Internal build identifier (must always increment)

## How It Works

### Automatic Version Injection

Flutter automatically reads the version from `pubspec.yaml` and injects it into platform-specific builds:

- **iOS**: 
  - `CFBundleShortVersionString` = Version (e.g., `1.0.0`)
  - `CFBundleVersion` = Build Number (e.g., `2`)
- **Android**:
  - `versionName` = Version (e.g., `1.0.0`)
  - `versionCode` = Build Number (e.g., `2`)

The `Info.plist` uses Flutter variables:
```xml
<key>CFBundleShortVersionString</key>
<string>$(FLUTTER_BUILD_NAME)</string>
<key>CFBundleVersion</key>
<string>$(FLUTTER_BUILD_NUMBER)</string>
```

**You do NOT need to manually change version numbers in Xcode or Android Studio.** Just update `pubspec.yaml` and Flutter handles the rest.

## Version Numbering Rules

### Semantic Versioning

Follow semantic versioning principles:

- **MAJOR** (1.x.x): Breaking changes, major feature releases
- **MINOR** (x.1.x): New features, backward compatible
- **PATCH** (x.x.1): Bug fixes, small improvements
- **BUILD** (+N): Always increment, even for same version

### Build Number Rules

**Critical:** Build numbers must **always increment** and can **never be reused**.

- ✅ Build `2` → Build `3` → Build `4`
- ❌ Cannot use build `2` again, even for a different version
- ❌ Cannot go backwards (e.g., `5` → `3`)

This is enforced by App Store Connect and Google Play Store.

## TestFlight Workflow

### For TestFlight Beta Testing

**Keep version the same, increment build number only:**

```yaml
# TestFlight Build 1
version: 1.0.0+2

# TestFlight Build 2 (bug fix)
version: 1.0.0+3

# TestFlight Build 3 (another fix)
version: 1.0.0+4

# TestFlight Build 4 (new feature, still testing)
version: 1.0.0+5
```

**Why?** TestFlight allows multiple builds with the same version but different build numbers. This lets you test fixes without changing the user-facing version.

### When Ready for App Store Release

```yaml
# Final TestFlight build
version: 1.0.0+5

# App Store Release (bug fix)
version: 1.0.1+6  # Increment PATCH and BUILD

# OR App Store Release (new feature)
version: 1.1.0+7  # Increment MINOR and BUILD
```

## Step-by-Step Workflow

### 1. Update Version in `pubspec.yaml`

Edit the version line:

```yaml
version: 1.0.0+3  # Change build number for next TestFlight
```

### 2. Build Archive

**Option A: Using Xcode (Recommended for TestFlight)**
1. Open project in Xcode
2. Select "Any iOS Device" as target
3. Product → Clean Build Folder (Shift + Cmd + K)
4. Product → Archive
5. Wait for archive to complete

**Option B: Using Flutter CLI**
```bash
flutter clean
flutter build ipa --release
```

The archive will be created at: `build/ios/archive/Runner.xcarchive`

### 3. Verify Version

In Xcode Organizer, check that the archive shows:
- **Version**: `1.0.0` (or your version)
- **Build**: `3` (or your build number)

### 4. Upload to TestFlight

1. In Xcode Organizer, select your archive
2. Click **"Distribute App"**
3. Choose **"App Store Connect"**
4. Select **"Upload"**
5. Follow the prompts to upload

## Common Scenarios

### Scenario 1: Bug Fix During Testing

**Current:** `1.0.0+2` (already in TestFlight)

**Action:**
```yaml
version: 1.0.0+3  # Increment build only
```

**Result:** New TestFlight build with same version, higher build number.

### Scenario 2: New Feature Release

**Current:** `1.0.0+5` (ready for release)

**Action:**
```yaml
version: 1.1.0+6  # Increment MINOR version and build
```

**Result:** New version with new features.

### Scenario 3: Critical Bug Fix Release

**Current:** `1.1.0+6` (in production)

**Action:**
```yaml
version: 1.1.1+7  # Increment PATCH version and build
```

**Result:** Bug fix release.

### Scenario 4: Major Version Update

**Current:** `1.5.0+15` (major changes)

**Action:**
```yaml
version: 2.0.0+16  # Increment MAJOR version and build
```

**Result:** Major version with breaking changes.

## Best Practices

### ✅ DO:

1. **Always increment build number** for every build (TestFlight or production)
2. **Keep version same** for multiple TestFlight builds of the same release
3. **Update version** when releasing to App Store (unless it's the same build)
4. **Use semantic versioning** (MAJOR.MINOR.PATCH)
5. **Clean build folder** before archiving (`flutter clean` or Xcode Clean)
6. **Verify version** in Xcode Organizer before uploading

### ❌ DON'T:

1. **Don't reuse build numbers** - once used, never use again
2. **Don't decrement build numbers** - always go forward
3. **Don't manually edit** Xcode project version settings
4. **Don't skip build numbers** unnecessarily (though it's technically allowed)
5. **Don't change version** for every TestFlight build (only increment build)

## Version History Example

Here's a realistic version history:

```
1.0.0+1  → Initial development build
1.0.0+2  → First TestFlight build
1.0.0+3  → TestFlight bug fix
1.0.0+4  → TestFlight another fix
1.0.0+5  → Final TestFlight before release
1.0.0+5  → App Store Release (same build)
1.0.1+6  → App Store bug fix release
1.0.1+7  → TestFlight for next version
1.1.0+8  → App Store feature release
1.1.0+9  → TestFlight for 1.2.0
1.2.0+10 → App Store feature release
```

## Troubleshooting

### Archive Shows Wrong Build Number

**Problem:** Archive shows old build number even after updating `pubspec.yaml`

**Solution:**
1. Run `flutter clean`
2. Clean Xcode build folder (Product → Clean Build Folder)
3. Rebuild archive
4. Verify in Xcode Organizer

### Build Number Already Used Error

**Problem:** App Store Connect rejects upload because build number was already used

**Solution:**
- Increment build number in `pubspec.yaml`
- Create new archive with higher build number
- Upload again

### Version Not Updating in Archive

**Problem:** Archive still shows old version after updating `pubspec.yaml`

**Solution:**
1. Verify `pubspec.yaml` has correct version
2. Run `flutter clean`
3. Rebuild from Flutter CLI first: `flutter build ios --release`
4. Then archive in Xcode

## Quick Reference

### Current Setup
- **Version Format:** `MAJOR.MINOR.PATCH+BUILD`
- **Location:** `pubspec.yaml` (line 19)
- **Auto-injected:** Yes, via Flutter build system
- **Manual Xcode changes:** Not required

### TestFlight Checklist

Before each TestFlight upload:
- [ ] Update build number in `pubspec.yaml`
- [ ] Run `flutter clean` (optional but recommended)
- [ ] Archive in Xcode
- [ ] Verify version/build in Organizer
- [ ] Upload to TestFlight

### App Store Release Checklist

Before App Store release:
- [ ] Update version number in `pubspec.yaml` (if needed)
- [ ] Update build number in `pubspec.yaml`
- [ ] Run `flutter clean`
- [ ] Archive in Xcode
- [ ] Verify version/build in Organizer
- [ ] Upload to App Store Connect
- [ ] Submit for review

## Additional Resources

- [Flutter Versioning Documentation](https://docs.flutter.dev/deployment/ios)
- [Apple App Store Versioning](https://developer.apple.com/documentation/xcode/versioning-your-app)
- [Semantic Versioning](https://semver.org/)

## Summary

**Key Takeaway:** 
- Update `pubspec.yaml` → Archive in Xcode → Done
- No manual Xcode changes needed
- Build number must always increment
- Version can stay same for TestFlight, increment for App Store releases

**Current Version:** Check `pubspec.yaml` line 19 for the current version and build number.

