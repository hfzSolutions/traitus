# Google Sign-In Setup Guide

This guide will help you complete the setup for Google Sign-In in your Traitus app.

## ✅ What's Already Implemented

1. ✅ Google Sign-In method added to `SupabaseService`
2. ✅ Google Sign-In method added to `AuthProvider`
3. ✅ **Google-branded button component** (`GoogleSignInButton`) that follows Google's Identity Guidelines
4. ✅ Google Sign-In button added to `auth_page.dart` (Login page)
5. ✅ Google Sign-In button added to `signup_page.dart` (Signup page)
6. ✅ iOS URL scheme configured in `Info.plist`
7. ✅ Android deep link configured in `AndroidManifest.xml`

## 🔧 Required Setup Steps

### Step 1: Enable Google Provider in Supabase

1. Go to your Supabase Dashboard: https://supabase.com/dashboard
2. Select your project
3. Navigate to **Authentication** → **Providers**
4. Find **Google** in the list and click on it
5. Toggle **Enable Google provider** to ON
6. You'll need to configure OAuth credentials (see Step 2)

### Step 2: Create Google OAuth Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Navigate to **APIs & Services** → **Credentials**
4. Click **Create Credentials** → **OAuth client ID**
5. If prompted, configure the OAuth consent screen:
   - Choose **External** (unless you have a Google Workspace)
   - Fill in the required information:
     - App name: `Traitus`
     - User support email: Your email
     - Developer contact: Your email
   - Add scopes: `email`, `profile`, `openid`
   - Add test users (if in testing mode)
6. Create OAuth client ID:
   - **Application type: Select "Web application"** ⚠️
     - **Why Web application?** Even though this is a Flutter mobile app, you need to select "Web application" because Supabase handles the OAuth flow through its web interface. The flow works like this:
       1. User taps "Continue with Google" in your app
       2. App opens Google's sign-in page in a browser/web view
       3. User authenticates with Google
       4. Google redirects to Supabase's web callback URL
       5. Supabase processes the authentication
       6. Supabase redirects back to your app via deep link (`com.hafiz.traitus://login-callback`)
     - This works for **both iOS and Android** - you only need ONE Web application client ID
   - Name: `Traitus Web` (or `Traitus OAuth`)
   - Authorized redirect URIs: Add your Supabase redirect URL:
     ```
     https://<your-project-ref>.supabase.co/auth/v1/callback
     ```
     - To find your project reference: Go to Supabase Dashboard → Settings → API → Your project URL will be `https://<project-ref>.supabase.co`
     - Example: `https://abcdefghijklmnop.supabase.co/auth/v1/callback`
7. Click **Create**
8. Copy the **Client ID** and **Client Secret** (you'll need both for Step 3)

### Step 3: Configure Google in Supabase

1. Back in Supabase Dashboard → **Authentication** → **Providers** → **Google**
2. Paste your **Client ID** and **Client Secret** from Step 2
3. Click **Save**

### Step 4: Configure Redirect URLs in Supabase

1. In Supabase Dashboard, go to **Authentication** → **URL Configuration**
2. Add the following to **Redirect URLs**:
   ```
   com.hafiz.traitus://login-callback
   ```
3. Click **Save**

### Step 5: Test Google Sign-In

1. Run your app:
   ```bash
   flutter run
   ```
2. On the login or signup page, tap **"Continue with Google"**
3. You should be redirected to Google's sign-in page
4. After signing in, you'll be redirected back to the app
5. The app should automatically log you in

## 📱 Platform-Specific Notes

### iOS
- URL scheme `com.hafiz.traitus` is configured in `Info.plist`
- Make sure your bundle identifier matches: `com.hafiz.traitus`

### Android
- Deep link `com.hafiz.traitus://` is configured in `AndroidManifest.xml`
- Make sure your package name matches: `com.hafiz.traitus`

## 🔍 Troubleshooting

### "Redirect URI mismatch" error
- Make sure you've added `com.hafiz.traitus://login-callback` to Supabase redirect URLs
- Verify the redirect URL in `lib/services/supabase_service.dart` matches exactly

### "Invalid client" error
- Double-check your Google OAuth Client ID and Secret in Supabase
- Make sure the redirect URI in Google Cloud Console includes your Supabase callback URL

### OAuth flow doesn't complete
- Check that your app's bundle ID/package name matches the URL scheme
- Verify deep link configuration in both iOS and Android
- Check app logs for detailed error messages

### Button doesn't appear
- Make sure you've run `flutter pub get` after any changes
- Check that the Google Sign-In button code is in both `auth_page.dart` and `signup_page.dart`

## 🎨 Customization

### Google Logo (Important for Branding Compliance)

**The button now follows Google's branding guidelines**, but you should add the official Google logo:

1. **Download the official Google logo:**
   - Go to [Google's Brand Resource Center](https://developers.google.com/identity/branding-guidelines)
   - Download the "Sign in with Google" button assets
   - Or download the Google logo directly from [Google's Brand Guidelines](https://about.google/brand-resource-center/logos-list/)

2. **Add the logo to your project:**
   - Save the Google logo as `assets/google_logo.png`
   - Recommended size: 18x18px (minimum) or 24x24px
   - Format: PNG with transparency

3. **Current implementation:**
   - The button uses `GoogleSignInButton` widget that follows Google's guidelines:
     - White background (#FFFFFF) in light mode
     - Dark background (#1F1F1F) in dark mode
     - Proper border colors (#DADCE0 light, #3C4043 dark)
     - 48px minimum height (Google's requirement)
     - 4px border radius (Google's standard)
     - Proper spacing and typography
   - If `google_logo.png` is missing, it shows a temporary fallback
   - **You should add the official logo for full compliance**

### Button Styling
The Google Sign-In button is now a reusable component:
- **Widget:** `lib/ui/widgets/google_sign_in_button.dart`
- **Usage:** Both `auth_page.dart` and `signup_page.dart` use the same component
- **Compliance:** Follows Google's Identity Guidelines for colors, spacing, and sizing

To customize, edit the `GoogleSignInButton` widget. However, be careful not to violate Google's branding guidelines:
- ✅ You can change text ("Sign in with Google" vs "Continue with Google")
- ✅ You can adjust padding/spacing slightly
- ❌ Don't change the core colors significantly
- ❌ Don't make the button smaller than 48px height
- ❌ Don't use non-standard border radius

## 📝 Notes

- Google Sign-In works for both **sign up** and **sign in** - if a user doesn't exist, Supabase will create an account automatically
- The OAuth flow uses Supabase's built-in OAuth handling, so no additional packages are needed
- User profile data (name, email, avatar) will be automatically synced from Google
- **One Web application client ID works for both iOS and Android** - you don't need separate iOS/Android client IDs for this implementation
- If you want to use native Google Sign-In SDKs in the future (for better UX), you would need additional iOS and Android client IDs, but the current Supabase OAuth approach works great and requires less setup

## ✅ Branding Compliance

**Yes, following Google's branding guidelines is important!**

The button implementation now follows Google's Identity Guidelines:
- ✅ Proper colors (white background, gray border)
- ✅ Correct sizing (48px minimum height)
- ✅ Proper spacing and typography
- ✅ Official Google logo support (you need to add the logo asset)
- ✅ Dark mode support

**Why it matters:**
- Required for app verification and compliance
- Builds user trust and recognition
- Consistent user experience across apps
- Avoids potential issues with Google's review process

**Next step:** Download and add the official Google logo to `assets/google_logo.png` for full compliance.

