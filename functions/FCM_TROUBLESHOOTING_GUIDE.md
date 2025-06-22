# Firebase Cloud Messaging (FCM) Troubleshooting Guide

## Current Issue Analysis

Based on your Firebase project status showing `firebase-core : disabled`, this is the primary cause of your notification issues.

## 🔧 Step-by-Step Fix

### 1. Enable Firebase Core (CRITICAL)

**Problem**: Your Firebase project shows `firebase-core : disabled`

**Solution**:
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `bloodbridge-4a327`
3. Go to **Project Settings** (gear icon)
4. Scroll down to **Your apps** section
5. If you don't see any apps, click **Add app** and choose **Web**
6. Register your app with a nickname (e.g., "Blood Donation Web")
7. This will enable Firebase Core services

### 2. Enable Firebase Cloud Messaging (FCM)

**Steps**:
1. In Firebase Console, go to **Messaging** in the left sidebar
2. If you see a setup prompt, follow it to enable FCM
3. Go to **Project Settings** → **Cloud Messaging** tab
4. Make sure FCM is enabled for your project

### 3. Verify Service Account Permissions

**Check if your service account has the right permissions**:
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project: `bloodbridge-4a327`
3. Go to **IAM & Admin** → **Service Accounts**
4. Find: `firebase-adminsdk-fbsvc@bloodbridge-4a327.iam.gserviceaccount.com`
5. Ensure it has these roles:
   - Firebase Admin
   - Cloud Functions Invoker
   - Service Account Token Creator

### 4. Deploy Updated Functions

Run these commands in your terminal:

```bash
cd functions
npm install
firebase deploy --only functions
```

### 5. Test FCM Configuration

Run the test script:

```bash
cd functions
node test_fcm_configuration.js
```

## 🚨 Common Error Codes & Solutions

### `messaging/permission-denied`
- **Cause**: FCM not enabled or insufficient permissions
- **Fix**: Enable FCM in Firebase Console

### `messaging/invalid-credential`
- **Cause**: Service account configuration issue
- **Fix**: Verify service account JSON and permissions

### `messaging/registration-token-not-registered`
- **Cause**: Device token is invalid or expired
- **Fix**: Refresh device tokens in your Flutter app

### `messaging/quota-exceeded`
- **Cause**: FCM quota limit reached
- **Fix**: Upgrade Firebase plan or wait for quota reset

## 📱 Flutter App Configuration

Make sure your Flutter app has:

1. **Firebase initialization** in `main.dart`
2. **FCM token generation** and storage
3. **Topic subscription** for notifications
4. **Proper notification handling**

## 🔍 Testing Steps

### 1. Test Service Account
```bash
cd functions
node -e "
const admin = require('firebase-admin');
admin.initializeApp();
console.log('Project ID:', admin.app().options.projectId);
"
```

### 2. Test FCM Sending
```bash
cd functions
node test_fcm_configuration.js
```

### 3. Test Function Deployment
```bash
firebase deploy --only functions
```

## 📊 Monitoring & Debugging

### Check Function Logs
```bash
firebase functions:log
```

### Monitor FCM Delivery
1. Go to Firebase Console → **Messaging**
2. Check **Analytics** tab for delivery reports

### Test with Firebase Console
1. Go to **Messaging** → **Send your first message**
2. Send a test notification to verify FCM is working

## 🎯 Expected Results

After fixing the issues, you should see:
- ✅ Firebase Core enabled
- ✅ FCM working properly
- ✅ Functions deploying successfully
- ✅ Notifications being sent and received

## 📞 Next Steps

1. **Enable Firebase Core** (most important)
2. **Deploy the updated functions**
3. **Run the test scripts**
4. **Test notifications in your Flutter app**

If you still have issues after following these steps, check the function logs for specific error messages. 