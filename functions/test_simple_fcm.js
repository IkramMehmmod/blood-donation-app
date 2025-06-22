const admin = require("firebase-admin");

// Initialize Firebase Admin
try {
  admin.initializeApp();
} catch (error) {
  console.log("Firebase Admin already initialized");
}

async function testSimpleFCM() {
  console.log("🧪 Testing Simple FCM...");
  
  try {
    // Test 1: Check if messaging is available
    const messaging = admin.messaging();
    console.log("✅ Messaging service available");
    
    // Test 2: Send a simple test message
    const testMessage = {
      notification: {
        title: "🎉 FCM Test Successful!",
        body: "Your Firebase Cloud Messaging is working correctly!"
      },
      data: {
        type: "test",
        message: "FCM is working!",
        timestamp: Date.now().toString()
      },
      topic: "test_topic" // This will only work if devices are subscribed
    };
    
    console.log("📤 Sending test message...");
    const result = await messaging.send(testMessage);
    console.log("✅ Test message sent successfully!");
    console.log("📋 Message ID:", result);
    
    return true;
    
  } catch (error) {
    console.log("❌ FCM test failed:", error.message);
    
    if (error.code === 'messaging/permission-denied') {
      console.log("💡 Solution: Enable FCM in Firebase Console");
    } else if (error.code === 'messaging/invalid-credential') {
      console.log("💡 Solution: Check service account configuration");
    } else if (error.code === 'messaging/registration-token-not-registered') {
      console.log("💡 This is normal - no devices are subscribed to the test topic");
    }
    
    return false;
  }
}

// Run the test
testSimpleFCM().then(success => {
  if (success) {
    console.log("\n🎉 FCM is working correctly!");
    console.log("💡 Your notifications should work in the Flutter app");
  } else {
    console.log("\n⚠️ FCM needs configuration");
    console.log("💡 Check the Firebase Console for FCM setup");
  }
}); 