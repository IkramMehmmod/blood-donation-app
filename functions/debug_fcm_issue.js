const admin = require("firebase-admin");

// Initialize with your service account
const serviceAccount = require("../blood_donation_app/bloodbridge-4a327-6969deca6803.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: "bloodbridge-4a327"
});

async function debugFCMIssue() {
  console.log("🔍 DEBUGGING FCM 404 ERROR");
  console.log("=" .repeat(50));
  console.log("📧 Service Account:", serviceAccount.client_email);
  console.log("🏗️ Project ID:", serviceAccount.project_id);
  console.log("⏰ Debug Time:", new Date().toISOString());
  console.log("=" .repeat(50));

  try {
    // Step 1: Check service account details
    console.log("\n🔍 Step 1: Service Account Analysis");
    console.log("-" .repeat(30));
    console.log("📧 Email:", serviceAccount.client_email);
    console.log("🏗️ Project ID:", serviceAccount.project_id);
    console.log("🔑 Private Key ID:", serviceAccount.private_key_id);
    console.log("🔗 Client ID:", serviceAccount.client_id);
    console.log("🌐 Auth URI:", serviceAccount.auth_uri);
    console.log("🔗 Token URI:", serviceAccount.token_uri);
    console.log("🔗 Cert URL:", serviceAccount.client_x509_cert_url);

    // Step 2: Test Firebase Admin initialization
    console.log("\n🔍 Step 2: Firebase Admin Initialization");
    console.log("-" .repeat(30));
    try {
      const app = admin.app();
      console.log("✅ Firebase Admin initialized successfully");
      console.log("🏗️ App name:", app.name);
      console.log("🏗️ App options:", JSON.stringify(app.options, null, 2));
    } catch (error) {
      console.log("❌ Firebase Admin initialization failed:", error.message);
    }

    // Step 3: Test FCM messaging object creation
    console.log("\n🔍 Step 3: FCM Messaging Object");
    console.log("-" .repeat(30));
    try {
      const messaging = admin.messaging();
      console.log("✅ FCM messaging object created successfully");
      console.log("🔧 Messaging object type:", typeof messaging);
    } catch (error) {
      console.log("❌ FCM messaging object creation failed:", error.message);
    }

    // Step 4: Test different FCM endpoints
    console.log("\n🔍 Step 4: FCM Endpoint Testing");
    console.log("-" .repeat(30));
    
    const testPayload = {
      notification: {
        title: "FCM Debug Test",
        body: "Testing FCM endpoints"
      },
      data: {
        debug: "true",
        timestamp: new Date().toISOString()
      }
    };

    // Test 4a: Send to topic
    console.log("📢 Testing sendToTopic...");
    try {
      const topicResult = await admin.messaging().sendToTopic("debug_test", testPayload);
      console.log("✅ sendToTopic successful:", topicResult);
    } catch (error) {
      console.log("❌ sendToTopic failed:");
      console.log("   Error Code:", error.code);
      console.log("   Error Message:", error.message);
      console.log("   Raw Response:", error.message.includes("Raw server response") ? 
        error.message.split("Raw server response:")[1] : "No raw response");
    }

    // Test 4b: Send to condition
    console.log("\n🎯 Testing sendToCondition...");
    try {
      const conditionResult = await admin.messaging().sendToCondition("'debug_test' in topics", testPayload);
      console.log("✅ sendToCondition successful:", conditionResult);
    } catch (error) {
      console.log("❌ sendToCondition failed:");
      console.log("   Error Code:", error.code);
      console.log("   Error Message:", error.message);
    }

    // Test 4c: Send to single token (mock)
    console.log("\n📱 Testing sendToDevice (mock token)...");
    try {
      const tokenResult = await admin.messaging().sendToDevice("mock_token_123", testPayload);
      console.log("✅ sendToDevice successful:", tokenResult);
    } catch (error) {
      console.log("❌ sendToDevice failed:");
      console.log("   Error Code:", error.code);
      console.log("   Error Message:", error.message);
    }

    // Step 5: Check project configuration
    console.log("\n🔍 Step 5: Project Configuration");
    console.log("-" .repeat(30));
    console.log("🏗️ Current project ID:", admin.app().options.projectId);
    console.log("🏗️ Service account project:", serviceAccount.project_id);
    console.log("✅ Projects match:", admin.app().options.projectId === serviceAccount.project_id);

    // Step 6: Test with minimal payload
    console.log("\n🔍 Step 6: Minimal Payload Test");
    console.log("-" .repeat(30));
    try {
      const minimalPayload = {
        data: {
          message: "Minimal test"
        }
      };
      
      const minimalResult = await admin.messaging().sendToTopic("minimal_debug", minimalPayload);
      console.log("✅ Minimal payload successful:", minimalResult);
    } catch (error) {
      console.log("❌ Minimal payload failed:");
      console.log("   Error Code:", error.code);
      console.log("   Error Message:", error.message);
    }

    // Step 7: Check if it's a permissions issue
    console.log("\n🔍 Step 7: Permissions Analysis");
    console.log("-" .repeat(30));
    console.log("🔑 Service account has these permissions:");
    console.log("   - Firebase Admin SDK access");
    console.log("   - Firestore access (confirmed working)");
    console.log("   - FCM access (needs verification)");
    
    console.log("\n💡 Possible causes of 404 error:");
    console.log("   1. FCM API not enabled for this project");
    console.log("   2. Service account missing FCM permissions");
    console.log("   3. Project ID mismatch in FCM service");
    console.log("   4. FCM service account not properly configured");

    // Step 8: Test with different initialization
    console.log("\n🔍 Step 8: Alternative Initialization Test");
    console.log("-" .repeat(30));
    try {
      // Try with explicit project ID
      const altApp = admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: "bloodbridge-4a327"
      }, "alt-app");
      
      const altMessaging = altApp.messaging();
      console.log("✅ Alternative initialization successful");
      
      const altResult = await altMessaging.sendToTopic("alt_test", testPayload);
      console.log("✅ Alternative FCM test successful:", altResult);
      
      // Clean up
      await altApp.delete();
    } catch (error) {
      console.log("❌ Alternative initialization failed:", error.message);
    }

  } catch (error) {
    console.error("💥 FCM debugging failed:", error);
    console.error("Full error:", JSON.stringify(error, null, 2));
  }
}

// Run the debugging
debugFCMIssue()
  .then(() => {
    console.log("\n🎉 FCM debugging completed");
    console.log("\n💡 Next steps:");
    console.log("   1. Check the error details above");
    console.log("   2. Verify FCM API is enabled in Google Cloud Console");
    console.log("   3. Check service account IAM roles");
    console.log("   4. Try the solutions provided");
    process.exit(0);
  })
  .catch((error) => {
    console.error("💥 Debugging failed:", error);
    process.exit(1);
  }); 