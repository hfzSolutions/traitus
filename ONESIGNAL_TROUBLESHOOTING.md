# OneSignal Push Notifications Troubleshooting

## Issue: "Your app is missing Push Notifications in Xcode"

If you're seeing this error from OneSignal, follow these steps to fix it.

## ✅ Current Configuration Status

Your project files are correctly configured:
- ✅ Push Notifications capability enabled in `project.pbxproj`
- ✅ Entitlements file configured with `aps-environment: production`
- ✅ Background Modes with `remote-notification` in `Info.plist`

## 🔧 Fix Steps

### Step 1: Verify in Xcode

1. **Open the workspace** (NOT the .xcodeproj):
   ```bash
   open ios/Runner.xcworkspace
   ```

2. **Select the Runner target**:
   - In the left sidebar, click on the project name (top item)
   - Under "TARGETS", select **Runner**

3. **Check Signing & Capabilities tab**:
   - Click on the **"Signing & Capabilities"** tab
   - Look for **"Push Notifications"** in the list of capabilities
   
   **If Push Notifications is MISSING:**
   - Click the **"+ Capability"** button (top left)
   - Search for and add **"Push Notifications"**
   - It should appear in your capabilities list

4. **Verify Background Modes**:
   - Look for **"Background Modes"** in the capabilities list
   - If it's missing, add it using "+ Capability"
   - Make sure **"Remote notifications"** is checked/enabled

### Step 2: Clean and Rebuild

After adding/verifying the capabilities:

1. **Clean Build Folder**:
   - In Xcode: **Product** → **Clean Build Folder** (or press `Shift + Cmd + K`)

2. **Build the Project**:
   - In Xcode: **Product** → **Build** (or press `Cmd + B`)
   - Make sure it builds without errors

### Step 3: Create a New Build

**⚠️ IMPORTANT**: You MUST create a new build after enabling Push Notifications!

1. **Archive the App**:
   - In Xcode: **Product** → **Archive**
   - Wait for the archive to complete (may take a few minutes)

2. **Upload to TestFlight**:
   - Once archive completes, the Organizer window opens
   - Select your archive and click **"Distribute App"**
   - Choose **"App Store Connect"**
   - Select **"Upload"** (not "Export")
   - Follow the prompts to upload
   - Wait for processing (usually 10-30 minutes)

3. **Test the New Build**:
   - Once processed, install the new build from TestFlight
   - The app will now have push notification capabilities enabled
   - OneSignal should detect the capability correctly

### Step 4: Verify OneSignal Configuration

1. **Check APNs Configuration in OneSignal**:
   - Go to OneSignal dashboard → **Settings** → **Platforms** → **Apple iOS**
   - Verify your APNs Auth Key is uploaded
   - Make sure you selected **"Flutter"** as the SDK

2. **Test Subscription**:
   - Install the new build on a test device
   - Open the app and grant notification permissions
   - Check OneSignal dashboard → **Audience** → **All Users**
   - Your device should appear as subscribed

## 🔍 Verification Script

Run the verification script to check your configuration:

```bash
cd ios
./verify_push_setup.sh
```

This will check:
- ✅ Entitlements file configuration
- ✅ APNs environment setting
- ✅ Background Modes configuration
- ✅ Push capability in project file

## 🐛 Common Issues

### Issue: Capability shows in Xcode but OneSignal still says it's missing

**Solution**: 
- Make sure you uploaded a NEW build to TestFlight after enabling the capability
- Old builds don't have the capability, even if it's enabled in Xcode
- Delete the old build from TestFlight and upload a fresh one

### Issue: Build fails after adding capability

**Solution**:
- Make sure your Apple Developer account has Push Notifications enabled
- Check that your provisioning profile includes Push Notifications
- Try regenerating your provisioning profile in Apple Developer Portal

### Issue: Notifications work in development but not in TestFlight

**Solution**:
- Make sure `aps-environment` is set to `production` in `Runner.entitlements`
- Development builds use `development`, but TestFlight requires `production`
- This has been fixed in your entitlements file

## 📝 Files to Check

1. **`ios/Runner/Runner.entitlements`**:
   ```xml
   <key>aps-environment</key>
   <string>production</string>
   ```

2. **`ios/Runner/Info.plist`**:
   ```xml
   <key>UIBackgroundModes</key>
   <array>
       <string>remote-notification</string>
   </array>
   ```

3. **`ios/Runner.xcodeproj/project.pbxproj`**:
   Should contain:
   ```
   SystemCapabilities = {
       com.apple.Push = {
           enabled = 1;
       };
   };
   ```

## ✅ Success Checklist

- [ ] Push Notifications capability visible in Xcode → Signing & Capabilities
- [ ] Background Modes capability visible with "Remote notifications" enabled
- [ ] Clean build folder completed
- [ ] Project builds successfully
- [ ] New archive created and uploaded to TestFlight
- [ ] New build installed from TestFlight
- [ ] OneSignal dashboard shows device as subscribed
- [ ] Test notification received successfully

## 🆘 Still Having Issues?

If you've followed all steps and still see the error:

1. **Double-check in Xcode**: The capability MUST be visible in the UI, not just in the project file
2. **Check OneSignal Dashboard**: Verify APNs configuration is complete
3. **Check Device Logs**: Look for OneSignal initialization messages
4. **Contact Support**: OneSignal support or check their troubleshooting docs

---

**Last Updated**: After fixing entitlements to use `production` environment

