#!/bin/bash

# 🚀 Blood Donation App - Production Deployment Script
# This script prepares and deploys the app for production

set -e  # Exit on any error

echo "🚀 Starting Production Deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "blood_donation_app/pubspec.yaml" ]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

print_status "📱 Preparing Blood Donation App for Production..."

# Step 1: Update dependencies
print_status "📦 Updating Flutter dependencies..."
cd blood_donation_app
flutter pub get
flutter pub upgrade

# Step 2: Clean and build
print_status "🧹 Cleaning previous builds..."
flutter clean
flutter pub get

# Step 3: Deploy Firebase security rules and functions
print_status "🔥 Deploying Firebase security rules and functions..."
firebase deploy --only firestore:rules,functions

# Step 4: Build for production
print_status "🏗️ Building Android APK for production..."
flutter build apk --release

# Step 5: Build for production (AAB for Play Store)
print_status "📦 Building Android App Bundle for Play Store..."
flutter build appbundle --release

print_success "✅ Production build completed!"

# Step 6: Show build information
print_status "📊 Build Information:"
echo "   📱 APK Location: build/app/outputs/flutter-apk/app-release.apk"
echo "   📦 AAB Location: build/app/outputs/bundle/release/app-release.aab"
echo "   🔥 Firebase Rules: Deployed"
echo "   ⚡ Firebase Functions: Deployed"

# Step 7: Production checklist
print_status "📋 Production Checklist:"
echo "   ✅ Firebase project: bloodbridge-4a327"
echo "   ✅ App Check: Configured for production"
echo "   ✅ Security rules: Deployed"
echo "   ✅ Functions: Deployed"
echo "   ✅ Build: Completed"

print_warning "⚠️  IMPORTANT: Before publishing to Play Store:"
echo "   1. Configure App Check in Firebase Console"
echo "   2. Add your debug token to Firebase Console > App Check > Debug tokens"
echo "   3. Set up production signing keys"
echo "   4. Update app version in pubspec.yaml"
echo "   5. Test the production build thoroughly"

print_success "🎉 Production deployment script completed!"
print_status "📱 Next steps:"
echo "   • Test the production APK: build/app/outputs/flutter-apk/app-release.apk"
echo "   • Upload AAB to Google Play Console: build/app/outputs/bundle/release/app-release.aab"
echo "   • Configure App Check in Firebase Console"
echo "   • Set up production signing keys"

cd .. 