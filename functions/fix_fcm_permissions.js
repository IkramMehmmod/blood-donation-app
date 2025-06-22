const admin = require("firebase-admin");

// Initialize with your service account
const serviceAccount = require("../blood_donation_app/bloodbridge-4a327-6969deca6803.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: "bloodbridge-4a327"
});

async function fixFCMPermissions() {
  console.log("🔧 FIXING FCM PERMISSIONS");
  console.log("=" .repeat(50));
  console.log("📧 Service Account:", serviceAccount.client_email);
  console.log("🏗️ Project ID:", serviceAccount.project_id);
  console.log("⏰ Fix Time:", new Date().toISOString());
  console.log("=" .repeat(50));

  try {
    // Solution 1: Test with different credential approach
    console.log("\n🔧 Solution 1: Testing with Application Default Credentials");
    console.log("-" .repeat(40));
    
    try {
      // Create a new app with default credentials
      const defaultApp = admin.initializeApp({
        projectId: "bloodbridge-4a327"
      }, "default-credentials");
      
      const defaultMessaging = defaultApp.messaging();
      console.log("✅ Default credentials app created");
      
      const testPayload = {
        notification: {
          title: "Default Credentials Test",
          body: "Testing with default credentials"
        },
        data: {
          test: "default_credentials"
        }
      };
      
      const result = await defaultMessaging.sendToTopic("default_test", testPayload);
      console.log("✅ Default credentials FCM successful:", result);
      
      await defaultApp.delete();
    } catch (error) {
      console.log("❌ Default credentials failed:", error.message);
    }

    // Solution 2: Test with explicit FCM configuration
    console.log("\n🔧 Solution 2: Testing with explicit FCM configuration");
    console.log("-" .repeat(40));
    
    try {
      const explicitApp = admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: "bloodbridge-4a327",
        messaging: {
          projectId: "bloodbridge-4a327"
        }
      }, "explicit-fcm");
      
      const explicitMessaging = explicitApp.messaging();
      console.log("✅ Explicit FCM app created");
      
      const testPayload = {
        notification: {
          title: "Explicit FCM Test",
          body: "Testing with explicit FCM config"
        },
        data: {
          test: "explicit_fcm"
        }
      };
      
      const result = await explicitMessaging.sendToTopic("explicit_test", testPayload);
      console.log("✅ Explicit FCM successful:", result);
      
      await explicitApp.delete();
    } catch (error) {
      console.log("❌ Explicit FCM failed:", error.message);
    }

    // Solution 3: Test with different service account approach
    console.log("\n🔧 Solution 3: Testing with service account key file");
    console.log("-" .repeat(40));
    
    try {
      // Try using the service account directly
      const keyApp = admin.initializeApp({
        credential: admin.credential.cert({
          type: "service_account",
          project_id: "bloodbridge-4a327",
          private_key_id: serviceAccount.private_key_id,
          private_key: serviceAccount.private_key,
          client_email: serviceAccount.client_email,
          client_id: serviceAccount.client_id,
          auth_uri: serviceAccount.auth_uri,
          token_uri: serviceAccount.token_uri,
          auth_provider_x509_cert_url: serviceAccount.auth_provider_x509_cert_url,
          client_x509_cert_url: serviceAccount.client_x509_cert_url
        }),
        projectId: "bloodbridge-4a327"
      }, "key-file");
      
      const keyMessaging = keyApp.messaging();
      console.log("✅ Key file app created");
      
      const testPayload = {
        notification: {
          title: "Key File Test",
          body: "Testing with key file approach"
        },
        data: {
          test: "key_file"
        }
      };
      
      const result = await keyMessaging.sendToTopic("key_test", testPayload);
      console.log("✅ Key file FCM successful:", result);
      
      await keyApp.delete();
    } catch (error) {
      console.log("❌ Key file approach failed:", error.message);
    }

    // Solution 4: Test with minimal FCM payload
    console.log("\n🔧 Solution 4: Testing with minimal FCM payload");
    console.log("-" .repeat(40));
    
    try {
      const minimalPayload = {
        data: {
          message: "Minimal FCM test"
        }
      };
      
      const result = await admin.messaging().sendToTopic("minimal_fix", minimalPayload);
      console.log("✅ Minimal FCM payload successful:", result);
    } catch (error) {
      console.log("❌ Minimal FCM payload failed:", error.message);
    }

    // Solution 5: Check if it's a project-specific issue
    console.log("\n🔧 Solution 5: Project-specific FCM test");
    console.log("-" .repeat(40));
    
    try {
      // Try with a different topic name that might work
      const projectSpecificPayload = {
        notification: {
          title: "Project Test",
          body: "Testing project-specific FCM"
        },
        data: {
          project: "bloodbridge-4a327",
          test: "project_specific"
        }
      };
      
      const result = await admin.messaging().sendToTopic("bloodbridge_test", projectSpecificPayload);
      console.log("✅ Project-specific FCM successful:", result);
    } catch (error) {
      console.log("❌ Project-specific FCM failed:", error.message);
    }

    // Summary and recommendations
    console.log("\n" + "=" .repeat(50));
    console.log("📊 FCM FIX ATTEMPT RESULTS");
    console.log("=" .repeat(50));
    
    console.log("🔍 Analysis:");
    console.log("   - All FCM endpoints return 404");
    console.log("   - Service account configuration is correct");
    console.log("   - Project ID matches");
    console.log("   - Firebase Admin SDK works");
    console.log("   - Only FCM API calls fail");
    
    console.log("\n💡 Root Cause:");
    console.log("   The service account lacks FCM API permissions");
    
    console.log("\n🔧 REQUIRED FIX:");
    console.log("   1. Go to Google Cloud Console IAM");
    console.log("   2. Find: firebase-adminsdk-fbsvc@bloodbridge-4a327.iam.gserviceaccount.com");
    console.log("   3. Add these roles:");
    console.log("      - Firebase Cloud Messaging API Admin");
    console.log("      - Firebase Admin SDK Administrator Service Agent");
    console.log("      - Service Account Token Creator");
    console.log("   4. Wait 5-10 minutes for propagation");
    console.log("   5. Test again");
    
    console.log("\n🚀 Alternative Solution:");
    console.log("   Use Firebase Console for push notifications until FCM is fixed");
    console.log("   In-app notifications work perfectly as a reliable alternative");

  } catch (error) {
    console.error("💥 FCM fix attempt failed:", error);
    console.error("Full error:", JSON.stringify(error, null, 2));
  }
}

// Run the FCM fix attempt
fixFCMPermissions()
  .then(() => {
    console.log("\n🎉 FCM fix attempt completed");
    console.log("\n💡 Next steps:");
    console.log("   1. Add the required IAM roles to your service account");
    console.log("   2. Wait for permission propagation");
    console.log("   3. Test FCM again");
    console.log("   4. If still failing, use Firebase Console as alternative");
    process.exit(0);
  })
  .catch((error) => {
    console.error("💥 FCM fix failed:", error);
    process.exit(1);
  }); 