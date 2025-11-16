#!/bin/bash

echo "🔍 Verifying Push Notifications Setup..."
echo ""

# Check if entitlements file exists
if [ -f "Runner/Runner.entitlements" ]; then
    echo "✅ Entitlements file exists"
    
    # Check for aps-environment
    if grep -q "aps-environment" Runner/Runner.entitlements; then
        ENV=$(grep -A 1 "aps-environment" Runner/Runner.entitlements | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
        echo "✅ APNs environment: $ENV"
        if [ "$ENV" != "production" ]; then
            echo "⚠️  Warning: APNs environment is set to '$ENV'. For TestFlight/App Store, it should be 'production'"
        fi
    else
        echo "❌ Missing aps-environment in entitlements"
    fi
else
    echo "❌ Entitlements file not found"
fi

echo ""

# Check Info.plist for background modes
if [ -f "Runner/Info.plist" ]; then
    if grep -q "UIBackgroundModes" Runner/Info.plist && grep -q "remote-notification" Runner/Info.plist; then
        echo "✅ Background Modes with remote-notification configured in Info.plist"
    else
        echo "❌ Missing UIBackgroundModes with remote-notification in Info.plist"
    fi
else
    echo "❌ Info.plist not found"
fi

echo ""

# Check project.pbxproj for Push capability
PROJECT_FILE="Runner.xcodeproj/project.pbxproj"
if [ -f "$PROJECT_FILE" ]; then
    if grep -q "com.apple.Push" "$PROJECT_FILE" && grep -A 1 "com.apple.Push" "$PROJECT_FILE" | grep -q "enabled = 1"; then
        echo "✅ Push Notifications capability enabled in project.pbxproj"
    else
        echo "❌ Push Notifications capability not found or not enabled in project.pbxproj"
    fi
else
    echo "❌ project.pbxproj not found at $PROJECT_FILE"
fi

echo ""
echo "📋 Next Steps:"
echo "1. Open ios/Runner.xcworkspace in Xcode"
echo "2. Select the 'Runner' target"
echo "3. Go to 'Signing & Capabilities' tab"
echo "4. Verify 'Push Notifications' capability is listed"
echo "5. If missing, click '+ Capability' and add 'Push Notifications'"
echo "6. Verify 'Background Modes' is listed with 'Remote notifications' enabled"
echo "7. Clean build folder (Shift+Cmd+K)"
echo "8. Build the app (Cmd+B)"
echo "9. Archive and upload a new build to TestFlight"
echo ""

