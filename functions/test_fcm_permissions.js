const admin = require("firebase-admin");

// Initialize with your service account
const serviceAccount = require("../blood_donation_app/bloodbridge-4a327-6969deca6803.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: "bloodbridge-4a327"
});

async function testFCMPermissions() {
  console.log("🔍 Testing FCM Permissions After Role Updates...");
  console.log("📧 Service Account Email:", serviceAccount.client_email);
  console.log("🏗️ Project ID:", serviceAccount.project_id);
  console.log("⏰ Testing at:", new Date().toISOString());
  
  try {
    // Test 1: Check if we can access FCM
    console.log("\n✅ Test 1: Checking FCM access...");
    const messaging = admin.messaging();
    console.log("✅ FCM messaging object created successfully");
    
    // Test 2: Try to send a test message to a topic
    console.log("\n✅ Test 2: Sending test message to topic...");
    const testPayload = {
      notification: {
        title: "FCM Permission Test",
        body: "Testing FCM permissions after role updates"
      },
      data: {
        test: "true",
        timestamp: new Date().toISOString()
      }
    };
    
    console.log("📤 Sending payload:", JSON.stringify(testPayload, null, 2));
    
    const result = await messaging.sendToTopic("test_topic", testPayload);
    console.log("✅ Test message sent successfully!");
    console.log("📊 Message ID:", result);
    
    // Test 3: Try sending to a blood group topic (like your app uses)
    console.log("\n✅ Test 3: Testing blood group topic...");
    const bloodGroupPayload = {
      notification: {
        title: "Blood Request Test",
        body: "Testing blood group topic notifications"
      },
      data: {
        type: "blood_request",
        bloodGroup: "A+",
        test: "true"
      }
    };
    
    const bloodResult = await messaging.sendToTopic("blood_a_pos", bloodGroupPayload);
    console.log("✅ Blood group topic message sent successfully!");
    console.log("📊 Message ID:", bloodResult);
    
  } catch (error) {
    console.error("❌ FCM Test Failed:");
    console.error("Error Code:", error.code);
    console.error("Error Message:", error.message);
    console.error("Full Error:", JSON.stringify(error, null, 2));
    
    if (error.code === 'messaging/registration-token-not-registered') {
      console.log("\n💡 This error is expected - the topic doesn't exist yet");
      console.log("✅ FCM is working correctly! The 404 error should be resolved.");
    } else if (error.code === 'messaging/quota-exceeded') {
      console.log("\n💡 Quota exceeded - this means FCM is working but you've hit limits");
    } else if (error.code === 'messaging/authentication-error') {
      console.log("\n💡 Authentication error - check service account permissions");
      console.log("🔧 Make sure the service account has 'Firebase Cloud Messaging API Admin' role");
    } else if (error.code === 'messaging/server-unavailable') {
      console.log("\n💡 Server unavailable - FCM API might be having issues");
    } else if (error.code === 'messaging/invalid-argument') {
      console.log("\n💡 Invalid argument - check payload structure");
    } else if (error.code === 'messaging/unknown-error' && error.message.includes('404')) {
      console.log("\n💡 Still getting 404 Error - FCM API not accessible");
      console.log("🔧 Additional steps needed:");
      console.log("   1. Wait a few more minutes for role propagation");
      console.log("   2. Check if FCM API is enabled in the correct project");
      console.log("   3. Verify service account has all required roles");
    } else {
      console.log("\n💡 Unknown error - check Firebase project configuration");
    }
  }
}

// Run the test
testFCMPermissions()
  .then(() => {
    console.log("\n🎉 FCM permission test completed");
    process.exit(0);
  })
  .catch((error) => {
    console.error("💥 Test failed:", error);
    process.exit(1);
  }); 