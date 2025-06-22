const admin = require("firebase-admin");
const path = require("path");

// Load service account explicitly
const serviceAccountPath = path.join(__dirname, '..', 'blood_donation_app', 'bloodbridge-4a327-6969deca6803.json');

async function testFCMWithServiceAccount() {
  console.log("🔍 Testing FCM with explicit service account...");
  
  try {
    // Initialize with explicit service account
    const serviceAccount = require(serviceAccountPath);
    
    // Initialize Firebase Admin with explicit configuration
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: "bloodbridge-4a327",
      databaseURL: "https://bloodbridge-4a327-default-rtdb.firebaseio.com"
    });
    
    console.log("✅ Firebase Admin initialized with service account");
    console.log("📋 Project ID:", admin.app().options.projectId);
    
    // Test FCM messaging
    const messaging = admin.messaging();
    console.log("✅ FCM messaging service available");
    
    // Test sending a simple message
    const testMessage = {
      notification: {
        title: "FCM Test",
        body: "Testing FCM functionality"
      },
      data: {
        type: "test",
        timestamp: Date.now().toString()
      },
      topic: "test_topic"
    };
    
    console.log("📤 Attempting to send FCM message...");
    const result = await messaging.send(testMessage);
    console.log("✅ FCM message sent successfully!");
    console.log("📋 Message ID:", result);
    
    // Test project configuration
    const projectId = admin.app().options.projectId;
    console.log("✅ Project ID confirmed:", projectId);
    
    if (projectId === "bloodbridge-4a327") {
      console.log("✅ Project ID matches expected value");
    } else {
      console.log("⚠️ Project ID mismatch");
    }
    
    console.log("\n🎉 FCM 404 Error Status:");
    console.log("✅ FCM is properly configured");
    console.log("✅ Service account is working");
    console.log("✅ Project ID is correctly set");
    console.log("✅ FCM messaging service is available");
    console.log("✅ Messages can be sent successfully");
    
    return true;
    
  } catch (error) {
    console.log("❌ FCM test failed:", error.message);
    
    if (error.code === 'messaging/permission-denied') {
      console.log("💡 FCM Permission denied - Enable FCM in Firebase Console");
    } else if (error.code === 'messaging/invalid-credential') {
      console.log("💡 Invalid credentials - Check service account");
    } else if (error.code === 'messaging/registration-token-not-registered') {
      console.log("💡 No devices subscribed to test topic (this is normal)");
    } else if (error.message.includes('404')) {
      console.log("💡 FCM 404 Error - Check if FCM is enabled in Firebase Console");
    } else {
      console.log("💡 Other error - Check Firebase project configuration");
    }
    
    return false;
  }
}

// Run the test
testFCMWithServiceAccount().then(success => {
  if (success) {
    console.log("\n🎉 FCM 404 Error is RESOLVED!");
    console.log("✅ Your FCM configuration is working correctly");
  } else {
    console.log("\n⚠️ FCM 404 Error may still exist");
    console.log("💡 Check Firebase Console for FCM setup");
  }
}); 