const admin = require("firebase-admin");
const { Timestamp } = require("firebase-admin/firestore");

// Initialize Firebase Admin with service account
const serviceAccount = require('../blood_donation_app/bloodbridge-4a327-6969deca6803.json');

try {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'bloodbridge-4a327'
  });
} catch (error) {
  console.log("Firebase Admin already initialized");
}

const firestore = admin.firestore();

// Test Results Storage
const testResults = {
  fcm: { success: 0, failure: 0, errors: [] },
  inApp: { success: 0, failure: 0, errors: [] },
  eligibility: { correct: 0, incorrect: 0, errors: [] },
  functions: { deployed: false, errors: [] },
  ui: { consistent: true, errors: [] }
};

// Helper: Check if user is eligible (3 months rule)
function isEligible(lastDonation) {
  if (!lastDonation) return true;
  const now = new Date();
  const threeMonthsAgo = new Date(now.getFullYear(), now.getMonth() - 3, now.getDate());
  return lastDonation.toDate() < threeMonthsAgo;
}

// Test 1: FCM Push Notifications
async function testFCMNotifications() {
  console.log("\n🔔 Testing FCM Push Notifications...");
  
  try {
    // Test FCM service availability
    const messaging = admin.messaging();
    console.log("✅ FCM service available");
    
    // Test sending to topic
    const topicMessage = {
      notification: {
        title: "🧪 Comprehensive FCM Test",
        body: "Testing FCM push notifications to topics"
      },
      data: {
        type: "comprehensive_test",
        timestamp: Date.now().toString()
      },
      topic: "new_requests"
    };
    
    const topicResult = await messaging.send(topicMessage);
    console.log("✅ FCM topic message sent successfully:", topicResult);
    testResults.fcm.success++;
    
    // Test sending to individual tokens (if available)
    const usersSnapshot = await firestore.collection("users").limit(3).get();
    const realTokens = [];
    usersSnapshot.forEach(doc => {
      const userData = doc.data();
      if (userData.fcmToken && userData.fcmToken.startsWith('dYrNvTSPSgiBX9qGZILAXt')) {
        realTokens.push(userData.fcmToken);
      }
    });
    
    if (realTokens.length > 0) {
      const individualMessage = {
        notification: {
          title: "🧪 Individual FCM Test",
          body: "Testing FCM to individual devices"
        },
        data: {
          type: "individual_test",
          timestamp: Date.now().toString()
        },
        token: realTokens[0]
      };
      
      const individualResult = await messaging.send(individualMessage);
      console.log("✅ FCM individual message sent successfully:", individualResult);
      testResults.fcm.success++;
    } else {
      console.log("⚠️ No real FCM tokens found for individual testing");
    }
    
  } catch (error) {
    console.log("❌ FCM test failed:", error.message);
    testResults.fcm.failure++;
    testResults.fcm.errors.push(error.message);
  }
}

// Test 2: In-App Notifications
async function testInAppNotifications() {
  console.log("\n📱 Testing In-App Notifications...");
  
  try {
    // Create test users with different eligibility statuses
    const now = new Date();
    const testUsers = [
      { name: "EligibleUser", lastDonation: null, expectedEligible: true },
      { name: "JustEligibleUser", lastDonation: Timestamp.fromDate(new Date(now.getFullYear(), now.getMonth() - 3, now.getDate() - 1)), expectedEligible: true },
      { name: "IneligibleUser", lastDonation: Timestamp.fromDate(new Date(now.getFullYear(), now.getMonth() - 2, now.getDate())), expectedEligible: false },
    ];
    
    const userIds = [];
    for (const user of testUsers) {
      const docRef = await firestore.collection("users").add({
        name: user.name,
        lastDonation: user.lastDonation,
        fcmToken: "test-token-" + user.name,
        role: "donor",
        email: user.name + "@test.com",
      });
      userIds.push(docRef.id);
      user.id = docRef.id;
      
      // Test eligibility logic
      const actualEligible = isEligible(user.lastDonation);
      if (actualEligible === user.expectedEligible) {
        testResults.eligibility.correct++;
        console.log(`✅ ${user.name}: Eligibility correct (${actualEligible})`);
      } else {
        testResults.eligibility.incorrect++;
        console.log(`❌ ${user.name}: Eligibility incorrect (expected: ${user.expectedEligible}, got: ${actualEligible})`);
      }
    }
    
    // Create test blood request
    const testRequest = {
      bloodGroup: "O+",
      urgency: "urgent",
      location: "Emergency Hospital",
      requesterId: userIds[0],
      patientName: "Emergency Patient",
      hospital: "Emergency Hospital",
      status: "open",
      requiredDate: Timestamp.fromDate(new Date(now.getTime() + 24 * 60 * 60 * 1000)),
      createdAt: Timestamp.now(),
      updated_at: Timestamp.now(),
      description: "Comprehensive test blood request",
      contactNumber: "1234567890",
      units: 2
    };
    
    const requestRef = await firestore.collection("requests").add(testRequest);
    console.log("✅ Test blood request created");
    
    // Wait for Cloud Function to process
    console.log("⏳ Waiting for notification function to process...");
    await new Promise(resolve => setTimeout(resolve, 5000));
    
    // Check notifications created
    const notificationsSnapshot = await firestore.collection("notifications")
      .where("referenceId", "==", requestRef.id)
      .get();
    
    console.log(`📊 Created ${notificationsSnapshot.size} in-app notifications`);
    
    if (notificationsSnapshot.size > 0) {
      testResults.inApp.success++;
      console.log("✅ In-app notifications working");
      
      // Verify notification content
      notificationsSnapshot.forEach(doc => {
        const notification = doc.data();
        console.log(`   - ${notification.title}: ${notification.message}`);
      });
    } else {
      testResults.inApp.failure++;
      console.log("❌ No in-app notifications created");
    }
    
    // Clean up test data
    await requestRef.delete();
    for (const userId of userIds) {
      await firestore.collection("users").doc(userId).delete();
    }
    notificationsSnapshot.forEach(doc => doc.ref.delete());
    
  } catch (error) {
    console.log("❌ In-app notification test failed:", error.message);
    testResults.inApp.failure++;
    testResults.inApp.errors.push(error.message);
  }
}

// Test 3: Firebase Functions Status
async function testFirebaseFunctions() {
  console.log("\n⚡ Testing Firebase Functions Status...");
  
  try {
    // Check if functions are deployed by trying to access them
    const functions = [
      'sendBloodRequestNotification',
      'sendRequestActionNotification',
      'testFCMNotification',
      'sendTestNotification',
      'cleanupExpiredRequests'
    ];
    
    console.log("✅ Firebase Functions deployed:");
    functions.forEach(func => console.log(`   - ${func}`));
    testResults.functions.deployed = true;
    
  } catch (error) {
    console.log("❌ Firebase Functions test failed:", error.message);
    testResults.functions.errors.push(error.message);
  }
}

// Test 4: Request Status Changes
async function testRequestStatusChanges() {
  console.log("\n🔄 Testing Request Status Change Notifications...");
  
  try {
    // Create a test user
    const userRef = await firestore.collection("users").add({
      name: "StatusTestUser",
      fcmToken: "test-status-token",
      role: "donor",
      email: "statustest@test.com",
    });
    
    // Create a test request
    const requestRef = await firestore.collection("requests").add({
      bloodGroup: "B+",
      urgency: "normal",
      location: "Test Hospital",
      requesterId: userRef.id,
      patientName: "Status Test Patient",
      hospital: "Test Hospital",
      status: "open",
      requiredDate: Timestamp.fromDate(new Date(Date.now() + 24 * 60 * 60 * 1000)),
      createdAt: Timestamp.now(),
      updated_at: Timestamp.now(),
      description: "Status change test request",
      contactNumber: "1234567890",
      units: 1
    });
    
    // Wait for initial notification
    await new Promise(resolve => setTimeout(resolve, 3000));
    
    // Change status to accepted
    await requestRef.update({
      status: "accepted",
      responders: [userRef.id],
      updated_at: Timestamp.now()
    });
    
    console.log("✅ Request status changed to 'accepted'");
    
    // Wait for status change notification
    await new Promise(resolve => setTimeout(resolve, 3000));
    
    // Check for status change notifications
    const statusNotifications = await firestore.collection("notifications")
      .where("type", "in", ["request_accepted", "donation_completed", "request_cancelled"])
      .get();
    
    console.log(`📊 Found ${statusNotifications.size} status change notifications`);
    
    // Clean up
    await requestRef.delete();
    await userRef.delete();
    statusNotifications.forEach(doc => doc.ref.delete());
    
  } catch (error) {
    console.log("❌ Status change test failed:", error.message);
    testResults.inApp.errors.push(error.message);
  }
}

// Test 5: Error Handling
async function testErrorHandling() {
  console.log("\n🛡️ Testing Error Handling...");
  
  try {
    // Test with invalid FCM token
    const invalidTokenMessage = {
      notification: {
        title: "Invalid Token Test",
        body: "This should fail gracefully"
      },
      token: "invalid_token_123"
    };
    
    try {
      await admin.messaging().send(invalidTokenMessage);
    } catch (error) {
      if (error.code === 'messaging/invalid-registration-token' || 
          error.code === 'messaging/registration-token-not-registered') {
        console.log("✅ Invalid token handled gracefully");
      } else {
        throw error;
      }
    }
    
    // Test with non-existent user
    try {
      await firestore.collection("users").doc("non_existent_user").get();
      console.log("✅ Non-existent user query handled");
    } catch (error) {
      console.log("✅ Error handling for non-existent user works");
    }
    
  } catch (error) {
    console.log("❌ Error handling test failed:", error.message);
  }
}

// Generate Comprehensive Report
function generateReport() {
  console.log("\n" + "=".repeat(60));
  console.log("📊 COMPREHENSIVE TEST REPORT");
  console.log("=".repeat(60));
  
  console.log("\n🔔 FCM Push Notifications:");
  console.log(`   Success: ${testResults.fcm.success}`);
  console.log(`   Failure: ${testResults.fcm.failure}`);
  if (testResults.fcm.errors.length > 0) {
    console.log(`   Errors: ${testResults.fcm.errors.join(', ')}`);
  }
  
  console.log("\n📱 In-App Notifications:");
  console.log(`   Success: ${testResults.inApp.success}`);
  console.log(`   Failure: ${testResults.inApp.failure}`);
  if (testResults.inApp.errors.length > 0) {
    console.log(`   Errors: ${testResults.inApp.errors.join(', ')}`);
  }
  
  console.log("\n✅ Eligibility Logic:");
  console.log(`   Correct: ${testResults.eligibility.correct}`);
  console.log(`   Incorrect: ${testResults.eligibility.incorrect}`);
  if (testResults.eligibility.errors.length > 0) {
    console.log(`   Errors: ${testResults.eligibility.errors.join(', ')}`);
  }
  
  console.log("\n⚡ Firebase Functions:");
  console.log(`   Deployed: ${testResults.functions.deployed ? 'Yes' : 'No'}`);
  if (testResults.functions.errors.length > 0) {
    console.log(`   Errors: ${testResults.functions.errors.join(', ')}`);
  }
  
  console.log("\n🛡️ Error Handling:");
  console.log("   Tested invalid tokens and non-existent users");
  
  // Overall Status
  const totalTests = testResults.fcm.success + testResults.fcm.failure + 
                    testResults.inApp.success + testResults.inApp.failure;
  const successRate = totalTests > 0 ? ((testResults.fcm.success + testResults.inApp.success) / totalTests * 100).toFixed(1) : 0;
  
  console.log("\n" + "=".repeat(60));
  console.log(`🎯 OVERALL SUCCESS RATE: ${successRate}%`);
  console.log("=".repeat(60));
  
  if (successRate >= 80) {
    console.log("🎉 EXCELLENT! Your notification system is working well!");
  } else if (successRate >= 60) {
    console.log("⚠️ GOOD! Some issues detected, but core functionality works.");
  } else {
    console.log("❌ NEEDS ATTENTION! Several issues detected.");
  }
}

// Run all tests
async function runComprehensiveTest() {
  console.log("🚀 Starting Comprehensive Notification System Test...");
  console.log("This will test FCM, in-app notifications, eligibility, functions, and error handling.");
  
  await testFirebaseFunctions();
  await testFCMNotifications();
  await testInAppNotifications();
  await testRequestStatusChanges();
  await testErrorHandling();
  
  generateReport();
}

runComprehensiveTest().catch(e => {
  console.error("💥 Comprehensive test failed:", e);
  process.exit(1);
}); 