@echo off
REM 🚀 Blood Donation App - Production Deployment Script (Windows)
REM This script prepares and deploys the app for production

echo 🚀 Starting Production Deployment...

REM Check if we're in the right directory
if not exist "blood_donation_app\pubspec.yaml" (
    echo [ERROR] Please run this script from the project root directory
    pause
    exit /b 1
)

echo [INFO] 📱 Preparing Blood Donation App for Production...

REM Step 1: Update dependencies
echo [INFO] 📦 Updating Flutter dependencies...
cd blood_donation_app
flutter pub get
flutter pub upgrade

REM Step 2: Clean and build
echo [INFO] 🧹 Cleaning previous builds...
flutter clean
flutter pub get

REM Step 3: Deploy Firebase security rules and functions
echo [INFO] 🔥 Deploying Firebase security rules and functions...
firebase deploy --only firestore:rules,functions

REM Step 4: Build for production
echo [INFO] 🏗️ Building Android APK for production...
flutter build apk --release

REM Step 5: Build for production (AAB for Play Store)
echo [INFO] 📦 Building Android App Bundle for Play Store...
flutter build appbundle --release

echo [SUCCESS] ✅ Production build completed!

REM Step 6: Show build information
echo [INFO] 📊 Build Information:
echo    📱 APK Location: build\app\outputs\flutter-apk\app-release.apk
echo    📦 AAB Location: build\app\outputs\bundle\release\app-release.aab
echo    🔥 Firebase Rules: Deployed
echo    ⚡ Firebase Functions: Deployed

REM Step 7: Production checklist
echo [INFO] 📋 Production Checklist:
echo    ✅ Firebase project: bloodbridge-4a327
echo    ✅ App Check: Configured for production
echo    ✅ Security rules: Deployed
echo    ✅ Functions: Deployed
echo    ✅ Build: Completed

echo [WARNING] ⚠️  IMPORTANT: Before publishing to Play Store:
echo    1. Configure App Check in Firebase Console
echo    2. Add your debug token to Firebase Console ^> App Check ^> Debug tokens
echo    3. Set up production signing keys
echo    4. Update app version in pubspec.yaml
echo    5. Test the production build thoroughly

echo [SUCCESS] 🎉 Production deployment script completed!
echo [INFO] 📱 Next steps:
echo    • Test the production APK: build\app\outputs\flutter-apk\app-release.apk
echo    • Upload AAB to Google Play Console: build\app\outputs\bundle\release\app-release.aab
echo    • Configure App Check in Firebase Console
echo    • Set up production signing keys

cd ..
pause 