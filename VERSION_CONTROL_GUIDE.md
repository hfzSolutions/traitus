# App Version Control & Force Update Guide

## Overview

This guide explains how to implement and manage app version control with force update capabilities. This system allows you to:

- **Force users to update** when critical bugs or security issues are fixed
- **Show optional update prompts** for new features
- **Enable maintenance mode** to prevent app usage during deployments
- **Control updates per platform** (iOS, Android, Web) or globally
- **Manage everything from the Supabase database** without code changes

## Architecture

### Components

1. **Database Table**: `app_version_control` - Stores version requirements and settings
2. **Model**: `AppVersionInfo` - Dart model for version information
3. **Service**: `VersionControlService` - Handles version checking logic
4. **UI**: `UpdateRequiredPage` - Shows update/maintenance screens
5. **Integration**: Modified `main.dart` - Checks version on app startup

## Setup Instructions

### 1. Run Database Migration

Execute the SQL migration in your Supabase SQL Editor:

```bash
# File: supabase_migration_add_app_version_control.sql
```

This creates:
- `app_version_control` table with all necessary columns
- Default records for iOS, Android, and "all" platforms
- Row Level Security (RLS) policies
- Triggers for automatic `updated_at` timestamps

### 2. Install Dependencies

The required dependencies are already added to `pubspec.yaml`:

```bash
flutter pub get
```

Dependencies:
- `package_info_plus: ^8.0.0` - Get current app version
- `url_launcher: ^6.3.0` - Open app store links

### 3. Configure Store URLs

Update the database records with your actual store URLs:

```sql
-- Update iOS App Store URL
UPDATE app_version_control
SET ios_app_store_url = 'https://apps.apple.com/app/your-app-id'
WHERE platform IN ('ios', 'all');

-- Update Android Play Store URL
UPDATE app_version_control
SET android_play_store_url = 'https://play.google.com/store/apps/details?id=com.yourcompany.traitus'
WHERE platform IN ('android', 'all');

-- Update Web App URL (if applicable)
UPDATE app_version_control
SET web_app_url = 'https://your-web-app.com'
WHERE platform IN ('web', 'all');
```

## Usage Guide

### Managing Versions from Database

#### Force Update Scenario

When you release version 1.1.0 with critical bug fixes:

```sql
UPDATE app_version_control
SET 
  latest_version = '1.1.0',
  latest_build_number = 10,
  minimum_version = '1.1.0',
  minimum_build_number = 10,
  force_update = true,
  update_message = 'Critical security update required. Please update to continue using the app.'
WHERE platform = 'all';
```

**Result**: All users with version < 1.1.0 (build < 10) will be blocked and forced to update.

#### Optional Update Scenario

When you release version 1.2.0 with new features:

```sql
UPDATE app_version_control
SET 
  latest_version = '1.2.0',
  latest_build_number = 15,
  minimum_version = '1.0.0',  -- Keep minimum low
  minimum_build_number = 1,
  force_update = false,
  show_update_prompt = true,
  update_message = 'New features available! Update to enjoy improved chat experience and bug fixes.'
WHERE platform = 'all';
```

**Result**: Users will see an optional update dialog but can choose "Maybe Later" and continue using the app.

#### Enable Maintenance Mode

During server maintenance or critical deployments:

```sql
UPDATE app_version_control
SET 
  maintenance_mode = true,
  maintenance_message = 'We are performing scheduled maintenance. The app will be back online in approximately 2 hours. Thank you for your patience!'
WHERE platform = 'all';
```

**Result**: All users will see a maintenance screen and cannot use the app.

#### Disable Maintenance Mode

After maintenance is complete:

```sql
UPDATE app_version_control
SET maintenance_mode = false
WHERE platform = 'all';
```

#### Platform-Specific Control

Control versions per platform (useful when releases are staggered):

```sql
-- Force update only for iOS
UPDATE app_version_control
SET 
  latest_version = '1.2.0',
  latest_build_number = 20,
  minimum_version = '1.2.0',
  minimum_build_number = 20,
  force_update = true
WHERE platform = 'ios';

-- Keep Android on older version (optional update)
UPDATE app_version_control
SET 
  latest_version = '1.2.0',
  latest_build_number = 20,
  minimum_version = '1.1.0',
  minimum_build_number = 15,
  force_update = false,
  show_update_prompt = true
WHERE platform = 'android';
```

### Version Comparison Logic

The system compares versions using:

1. **Build Number** (primary) - More specific, increments with each build
2. **Semantic Version** (secondary) - Major.Minor.Patch format

Example:
- Current: `1.0.5` (build 8)
- Required: `1.1.0` (build 10)
- **Result**: Update required (build 8 < 10)

### Platform Detection

The system automatically detects the platform:
- iOS devices use `ios` or `all` records
- Android devices use `android` or `all` records
- Web apps use `web` or `all` records

Platform-specific records take precedence over `all`.

## User Experience Flow

### App Startup Flow

1. **Launch app** → Show splash screen
2. **Check version** → Call `VersionControlService.checkVersion()`
3. **Evaluate result**:
   - **Maintenance mode** → Show maintenance screen (blocking)
   - **Force update** → Show update required screen (blocking)
   - **Optional update** → Show dialog (dismissible)
   - **Up to date** → Continue to auth/home

### Update Required Screen

Features:
- ✅ Clear messaging about why update is needed
- ✅ Current vs required version display
- ✅ "Update Now" button → Opens app store
- ✅ "Check Again" button → Clears cache and rechecks version from database
- ✅ Auto-updates when version requirements change
- ❌ No dismiss option (for force updates)

### Optional Update Dialog

Features:
- ✅ Friendly prompt about new features
- ✅ "Update" button → Opens app store directly
- ✅ "Maybe Later" button → Dismisses dialog
- ✅ Only shown once per app session
- ✅ Lightweight and non-intrusive experience

### Maintenance Mode Screen

Features:
- ✅ Maintenance icon and messaging
- ✅ Custom maintenance message from database
- ✅ "Check Again" button → Clears cache and rechecks version from database
- ✅ Auto-updates UI when maintenance is disabled
- ❌ No app access until maintenance mode is disabled

## Database Schema Reference

### Table: `app_version_control`

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `platform` | TEXT | 'ios', 'android', 'web', or 'all' |
| `minimum_version` | TEXT | Minimum version required (e.g., "1.0.0") |
| `minimum_build_number` | INTEGER | Minimum build number required |
| `latest_version` | TEXT | Latest available version |
| `latest_build_number` | INTEGER | Latest build number |
| `force_update` | BOOLEAN | If true, enforce minimum version |
| `show_update_prompt` | BOOLEAN | Show optional update prompt |
| `update_message` | TEXT | Custom message for users |
| `update_title` | TEXT | Dialog/screen title |
| `ios_app_store_url` | TEXT | iOS App Store URL |
| `android_play_store_url` | TEXT | Google Play Store URL |
| `web_app_url` | TEXT | Web app URL |
| `maintenance_mode` | BOOLEAN | Enable maintenance mode |
| `maintenance_message` | TEXT | Maintenance screen message |
| `created_at` | TIMESTAMPTZ | Record creation time |
| `updated_at` | TIMESTAMPTZ | Last update time (auto-updated) |

### Constraints

- One record per platform (UNIQUE constraint)
- Platform must be one of: 'ios', 'android', 'web', 'all'

## Best Practices

### 1. Version Numbering

Follow semantic versioning:
```
MAJOR.MINOR.PATCH+BUILD

Examples:
- 1.0.0+1    → Initial release
- 1.0.1+2    → Bug fix
- 1.1.0+5    → New features
- 2.0.0+10   → Breaking changes
```

### 2. When to Force Update

Force updates when:
- ✅ Security vulnerabilities fixed
- ✅ Critical bugs affecting data integrity
- ✅ Breaking API changes
- ✅ Major backend incompatibilities

Avoid force updates for:
- ❌ Minor UI improvements
- ❌ New features (unless critical)
- ❌ Performance optimizations
- ❌ Cosmetic changes

### 3. Update Messages

**Good messages**:
- Clear and specific
- Mention benefits
- Friendly tone

```
"Critical security update required. Please update to keep your data safe."
"New features available! Update now to enjoy improved performance and new AI models."
"We've fixed several bugs that were affecting chat synchronization."
```

**Bad messages**:
- Vague or technical
- No explanation
- Demanding tone

```
"Update required."  ❌ Too vague
"Bug fixes."  ❌ Not helpful
"You must update immediately!"  ❌ Too aggressive
```

### 4. Maintenance Mode

Best practices:
- ✅ Schedule during low-usage hours
- ✅ Communicate duration estimate
- ✅ Provide status page link
- ✅ Test the enable/disable flow
- ✅ Have rollback plan

### 5. Testing

Before releasing version control updates:

```sql
-- Test maintenance mode
UPDATE app_version_control
SET maintenance_mode = true
WHERE platform = 'all';
-- Open app → Should show maintenance screen
-- Disable and test again

-- Test optional update
UPDATE app_version_control
SET 
  latest_version = '99.0.0',
  latest_build_number = 9999,
  force_update = false,
  show_update_prompt = true
WHERE platform = 'all';
-- Open app → Should show optional dialog

-- Test force update
UPDATE app_version_control
SET 
  minimum_version = '99.0.0',
  minimum_build_number = 9999,
  force_update = true
WHERE platform = 'all';
-- Open app → Should block with update screen

-- Reset to normal
UPDATE app_version_control
SET 
  minimum_version = '1.0.0',
  minimum_build_number = 1,
  latest_version = '1.0.0',
  latest_build_number = 1,
  force_update = false,
  maintenance_mode = false
WHERE platform = 'all';
```

## Monitoring & Analytics

### Recommended Monitoring

Track in your analytics:
1. Version distribution across users
2. Update adoption rate
3. Force update trigger frequency
4. User drop-off at update screen

### Query Examples

```sql
-- Check current version control settings
SELECT 
  platform,
  minimum_version,
  latest_version,
  force_update,
  maintenance_mode,
  updated_at
FROM app_version_control
ORDER BY platform;

-- View update history (add audit table if needed)
-- Consider creating an audit log for version changes

-- Count users by version (requires user_profiles modification)
-- Consider adding last_app_version column to user_profiles
```

## Troubleshooting

### Issue: Users stuck on update screen

**Check**:
1. Are store URLs correct?
2. Is the app actually available in stores?
3. Is force_update accidentally left enabled?

**Solution**:
```sql
-- Temporarily disable force update
UPDATE app_version_control
SET force_update = false
WHERE platform = 'all';
```

**User Action**:
Users can click "Check Again" button to fetch the latest version control settings from the database. The app will automatically update and allow access if restrictions are removed.

### Issue: Update prompt not showing

**Check**:
1. Is `show_update_prompt` enabled?
2. Is `latest_version` actually newer?
3. Has user already dismissed it this session?

**Solution**:
```sql
-- Verify settings
SELECT * FROM app_version_control WHERE platform = 'all';

-- Ensure show_update_prompt is true
UPDATE app_version_control
SET show_update_prompt = true
WHERE platform = 'all';
```

### Issue: Version check failing

**Possible causes**:
- Network issues
- Database connection problems
- RLS policies blocking reads

**Fallback behavior**:
The app gracefully handles errors and allows users to proceed if version check fails. This prevents lockouts due to network issues.

**User Action**:
If users encounter persistent issues, they can use the "Check Again" button which:
1. Clears the local cache (removes stale data)
2. Makes a fresh request to the database
3. Updates the UI immediately with the new status

### Issue: Wrong platform detected

**Check**:
- Platform detection logic in `VersionControlService.getCurrentPlatform()`
- Ensure you're testing on correct device/simulator

## Future Enhancements

Consider adding:
1. **Gradual rollout**: Force update only percentage of users
2. **User segments**: Different rules for beta users
3. **In-app updates**: Android in-app update API
4. **Version analytics**: Track adoption rates
5. **Scheduled maintenance**: Auto-enable/disable at specific times
6. **Multi-language support**: Localized messages
7. **Rich notifications**: Push notifications for updates
8. **Change logs**: Display what's new in updates

## API Reference

### VersionControlService

```dart
// Check current version against requirements
Future<VersionCheckStatus> checkVersion()

// Fetch version info from database (cached)
Future<AppVersionInfo?> fetchVersionInfo({bool forceRefresh = false})

// Get current app version
Future<PackageInfo> getPackageInfo()

// Get platform-specific store URL
String? getStoreUrl(AppVersionInfo versionInfo)

// Clear cache (force fresh check)
void clearCache()
```

### VersionCheckStatus

```dart
enum VersionCheckResult {
  upToDate,          // No action needed
  updateAvailable,   // Optional update
  updateRequired,    // Force update
  maintenanceMode,   // App blocked
}

class VersionCheckStatus {
  final VersionCheckResult result;
  final AppVersionInfo? versionInfo;
  final String? message;
  
  bool get needsUpdate;        // true if force update
  bool get hasOptionalUpdate;  // true if optional
  bool get inMaintenance;      // true if maintenance
  bool get canProceed;         // true if can use app
}
```

## Support

For issues or questions:
1. Check troubleshooting section above
2. Review Supabase logs for errors
3. Test with different version scenarios
4. Verify database records are correct

## Summary

This version control system provides:
- ✅ **Remote control** - Manage from database
- ✅ **Force updates** - Block old versions
- ✅ **Optional prompts** - Encourage updates
- ✅ **Maintenance mode** - Graceful downtime
- ✅ **Platform-specific** - Control per platform
- ✅ **User-friendly** - Clear messaging with actionable buttons
- ✅ **Real-time updates** - "Check Again" fetches fresh data instantly
- ✅ **Fail-safe** - Errors don't block users
- ✅ **Cached** - Minimize API calls (5-minute cache)
- ✅ **Responsive** - UI updates immediately when settings change

This is production-ready and follows industry best practices for mobile app version management.

