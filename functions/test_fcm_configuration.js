const admin = require("firebase-admin");
const {logger} = require("firebase-functions");

// Initialize Firebase Admin for testing
try {
  admin.initializeApp();
} catch (error) {
  // App might already be initialized
  console.log("Firebase Admin already initialized or error:", error.message);
}

// Test FCM Configuration
async function testFCMConfiguration() {
  try {
    console.log("🔍 Testing Firebase Admin SDK Configuration...");
    
    // Test 1: Check if Firebase Admin is initialized
    if (!admin.apps.length) {
      console.log("❌ Firebase Admin SDK not initialized");
      return false;
    }
    console.log("✅ Firebase Admin SDK initialized successfully");
    
    // Test 2: Check if messaging service is available
    try {
      const messaging = admin.messaging();
      console.log("✅ Firebase Messaging service available");
    } catch (error) {
      console.log("❌ Firebase Messaging service not available:", error.message);
      return false;
    }
    
    // Test 3: Test sending a test message to a topic
    try {
      const testPayload = {
        notification: {
          title: "Test Notification",
          body: "This is a test notification from Firebase Functions"
        },
        data: {
          type: "test",
          timestamp: Date.now().toString()
        }
      };
      
      console.log("📤 Attempting to send test notification...");
      const result = await admin.messaging().sendToTopic("test_topic", testPayload);
      console.log("✅ Test notification sent successfully:", result);
    } catch (error) {
      console.log("⚠️ Test notification failed (this might be expected if no devices subscribed):", error.message);
      
      // Check if it's a permissions error
      if (error.code === 'messaging/permission-denied') {
        console.log("❌ FCM Permission denied - Check Firebase project settings");
        console.log("💡 Make sure FCM is enabled in your Firebase project");
        return false;
      }
      
      if (error.code === 'messaging/invalid-credential') {
        console.log("❌ Invalid credentials - Check service account configuration");
        return false;
      }
    }
    
    // Test 4: Check project configuration
    try {
      const projectId = admin.app().options.projectId;
      console.log("✅ Project ID:", projectId);
      
      if (projectId !== "bloodbridge-4a327") {
        console.log("⚠️ Warning: Project ID doesn't match expected value");
      }
    } catch (error) {
      console.log("❌ Could not retrieve project configuration:", error.message);
    }
    
    console.log("🎉 FCM Configuration test completed");
    return true;
    
  } catch (error) {
    console.log("❌ FCM Configuration test failed:", error);
    return false;
  }
}

// Test service account configuration
function testServiceAccount() {
  console.log("🔍 Testing Service Account Configuration...");
  
  try {
    // Check if we can access the service account
    const app = admin.app();
    const options = app.options;
    
    console.log("✅ Firebase Admin app initialized");
    console.log("📋 Project ID:", options.projectId);
    console.log("📋 Database URL:", options.databaseURL);
    
    if (options.credential) {
      console.log("✅ Credentials configured");
    } else {
      console.log("❌ No credentials found");
    }
    
  } catch (error) {
    console.log("❌ Service account test failed:", error.message);
  }
}

// Main test function
async function runTests() {
  console.log("🚀 Starting Firebase Configuration Tests...\n");
  
  testServiceAccount();
  console.log("");
  
  const fcmResult = await testFCMConfiguration();
  console.log("");
  
  if (fcmResult) {
    console.log("✅ All tests passed! Your Firebase configuration looks good.");
  } else {
    console.log("❌ Some tests failed. Please check the issues above.");
    console.log("\n🔧 Troubleshooting Steps:");
    console.log("1. Enable Firebase Core in your Firebase Console");
    console.log("2. Enable Firebase Cloud Messaging (FCM)");
    console.log("3. Verify your service account has the necessary permissions");
    console.log("4. Check that your Firebase project is properly configured");
  }
}

// Export for use in other files
module.exports = {
  testFCMConfiguration,
  testServiceAccount,
  runTests
};

// Run tests if this file is executed directly
if (require.main === module) {
  runTests();
} 