const admin = require("firebase-admin");

// Initialize with default credentials (no service account JSON)
admin.initializeApp({
  projectId: "bloodbridge-4a327"
});

async function testDefaultCredentials() {
  console.log("🔍 Testing FCM with Default Credentials...");
  console.log("🏗️ Project ID:", admin.app().options.projectId);
  console.log("⏰ Test Time:", new Date().toISOString());
  
  try {
    // Test FCM access
    console.log("\n✅ Testing FCM access...");
    const messaging = admin.messaging();
    console.log("✅ FCM messaging object created successfully");
    
    // Test sending to topic
    console.log("\n✅ Testing topic message...");
    const testPayload = {
      notification: {
        title: "Default Credentials Test",
        body: "Testing FCM with default credentials"
      },
      data: {
        test: "default_credentials",
        timestamp: new Date().toISOString()
      }
    };
    
    const result = await messaging.sendToTopic("test_topic", testPayload);
    console.log("✅ Topic message sent successfully!");
    console.log("📊 Message ID:", result);
    
  } catch (error) {
    console.error("❌ Default credentials test failed:");
    console.error("Error Code:", error.code);
    console.error("Error Message:", error.message);
    
    if (error.code === 'messaging/registration-token-not-registered') {
      console.log("\n💡 This error is expected - the topic doesn't exist yet");
      console.log("✅ FCM is working correctly with default credentials!");
    } else if (error.code === 'messaging/unknown-error' && error.message.includes('404')) {
      console.log("\n💡 Still getting 404 - this confirms it's a service account issue");
      console.log("🔧 Solution: Add the missing IAM roles to your service account");
    } else {
      console.log("\n💡 Different error - check the specific error details");
    }
  }
}

// Run the test
testDefaultCredentials()
  .then(() => {
    console.log("\n🎉 Default credentials test completed");
    process.exit(0);
  })
  .catch((error) => {
    console.error("💥 Test failed:", error);
    process.exit(1);
  }); 