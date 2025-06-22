const admin = require("firebase-admin");

// Initialize with explicit project ID
admin.initializeApp({
  projectId: "bloodbridge-4a327"
});

async function testServiceAccount() {
  console.log("🔍 Testing Service Account Permissions...");
  
  try {
    // Test 1: Check if we can access Firestore
    console.log("\n✅ Test 1: Checking Firestore access...");
    const firestore = admin.firestore();
    const testDoc = await firestore.collection("test").doc("test").get();
    console.log("✅ Firestore access successful");
    
    // Test 2: Check if we can access FCM
    console.log("\n✅ Test 2: Checking FCM access...");
    const messaging = admin.messaging();
    console.log("✅ FCM messaging object created successfully");
    
    // Test 3: Try to get project info
    console.log("\n✅ Test 3: Getting project info...");
    const projectId = admin.app().options.projectId;
    console.log("✅ Project ID:", projectId);
    
    // Test 4: Try to send a simple test message
    console.log("\n✅ Test 4: Sending test FCM message...");
    const testPayload = {
      notification: {
        title: "Service Account Test",
        body: "Testing service account permissions"
      },
      data: {
        test: "true"
      }
    };
    
    // Try sending to a topic that might not exist (this should give us a different error)
    const result = await messaging.sendToTopic("service_account_test", testPayload);
    console.log("✅ Test message sent successfully!");
    console.log("📊 Message ID:", result);
    
  } catch (error) {
    console.error("❌ Service Account Test Failed:");
    console.error("Error Code:", error.code);
    console.error("Error Message:", error.message);
    
    if (error.code === 'messaging/registration-token-not-registered') {
      console.log("\n💡 This error is expected - the topic doesn't exist yet");
      console.log("✅ FCM is working correctly!");
    } else if (error.code === 'messaging/quota-exceeded') {
      console.log("\n💡 Quota exceeded - FCM is working but you've hit limits");
    } else if (error.code === 'messaging/authentication-error') {
      console.log("\n💡 Authentication error - service account needs FCM permissions");
    } else if (error.code === 'messaging/server-unavailable') {
      console.log("\n💡 Server unavailable - FCM API might be having issues");
    } else if (error.code === 'messaging/invalid-argument') {
      console.log("\n💡 Invalid argument - check payload structure");
    } else if (error.code === 'messaging/unknown-error' && error.message.includes('404')) {
      console.log("\n💡 404 Error - FCM API not accessible");
      console.log("🔧 Solutions:");
      console.log("   1. Enable Firebase Cloud Messaging API in Google Cloud Console");
      console.log("   2. Add 'Firebase Cloud Messaging API Admin' role to service account");
      console.log("   3. Check if project is properly configured");
    } else {
      console.log("\n💡 Unknown error - check Firebase project configuration");
      console.error("Full Error:", JSON.stringify(error, null, 2));
    }
  }
}

// Run the test
testServiceAccount()
  .then(() => {
    console.log("\n🎉 Service account test completed");
    process.exit(0);
  })
  .catch((error) => {
    console.error("💥 Test failed:", error);
    process.exit(1);
  }); 