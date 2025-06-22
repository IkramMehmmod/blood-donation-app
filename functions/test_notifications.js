const admin = require('firebase-admin');
const { logger } = require('firebase-functions');
const path = require('path');

// Initialize Firebase Admin with service account
const serviceAccount = require('../blood_donation_app/bloodbridge-4a327-6969deca6803.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'bloodbridge-4a327'
});

// Get Firestore instance
const firestore = admin.firestore();

// Android notification channel ID (must match Flutter app)
const ANDROID_CHANNEL_ID = "blood_donation_high_importance";

async function testLocalNotification() {
  try {
    console.log('🧪 Testing local notification via Firebase Functions...');
    
    // Create a test notification document in Firestore
    await firestore.collection('test_notifications').add({
      'userId': 'test_user',
      'title': '🧪 Test FCM Notification',
      'body': 'This is a test FCM notification from Firebase Functions!',
      'timestamp': admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log('✅ Test FCM notification document created');
    console.log('📝 Check Firebase Functions logs to see if the notification was sent');
  } catch (error) {
    console.error('❌ Error sending test FCM notification:', error);
  }
}

async function testTopicNotification() {
  try {
    console.log('🧪 Testing topic notification...');
    
    // Send to topic
    const testPayload = {
      notification: {
        title: "🧪 Test Topic Notification",
        body: "This is a test notification sent to all users via topic!",
      },
      data: {
        type: "test",
        referenceId: "test123",
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        channelId: ANDROID_CHANNEL_ID,
      },
    };
    
    await admin.messaging().sendToTopic("new_requests", testPayload);
    console.log("✅ Test topic notification sent to: new_requests");
  } catch (error) {
    console.error('❌ Error sending topic notification:', error);
  }
}

async function testIndividualNotification() {
  try {
    console.log('🧪 Testing individual notification...');
    
    // Get all users with FCM tokens
    const usersSnapshot = await firestore.collection("users").get();
    
    if (!usersSnapshot.empty) {
      const notificationPromises = [];
      
      usersSnapshot.forEach((doc) => {
        const userData = doc.data();
        if (userData.fcmToken) {
          const testPayload = {
            token: userData.fcmToken,
            notification: {
              title: "🧪 Test Individual Notification",
              body: `Hello ${userData.name || 'User'}! This is a test notification.`,
            },
            data: {
              type: "test",
              referenceId: "test123",
              click_action: "FLUTTER_NOTIFICATION_CLICK",
              channelId: ANDROID_CHANNEL_ID,
            },
          };
          
          notificationPromises.push(admin.messaging().send(testPayload));
        }
      });
      
      if (notificationPromises.length > 0) {
        await Promise.all(notificationPromises);
        console.log(`✅ Test individual notifications sent to ${notificationPromises.length} users`);
      } else {
        console.log('⚠️ No users with FCM tokens found');
      }
    } else {
      console.log('⚠️ No users found in database');
    }
  } catch (error) {
    console.error('❌ Error sending individual notifications:', error);
  }
}

async function testBloodRequestNotification() {
  try {
    console.log('🧪 Testing blood request notification...');
    
    // Create a test blood request
    await firestore.collection('requests').add({
      'bloodGroup': 'A+',
      'urgency': 'normal',
      'location': 'Test Hospital',
      'requesterId': 'test_requester',
      'patientName': 'Test Patient',
      'hospital': 'Test Hospital',
      'status': 'open',
      'createdAt': admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log('✅ Test blood request created');
    console.log('📝 Check Firebase Functions logs to see if the notification was sent');
  } catch (error) {
    console.error('❌ Error creating test blood request:', error);
  }
}

async function testNotificationsComprehensive() {
  console.log("🔍 Comprehensive Notification Test...");
  console.log("📧 Service Account:", serviceAccount.client_email);
  console.log("🏗️ Project ID:", serviceAccount.project_id);
  console.log("⏰ Test Time:", new Date().toISOString());
  
  try {
    // Test 1: Check if we can access FCM at all
    console.log("\n✅ Test 1: Basic FCM Access...");
    const messaging = admin.messaging();
    console.log("✅ FCM messaging object created successfully");
    
    // Test 2: Try different FCM endpoints
    console.log("\n✅ Test 2: Testing different FCM approaches...");
    
    // Approach 1: Send to a single device token (if we had one)
    console.log("📱 Approach 1: Single device token (skipping - no tokens available)");
    
    // Approach 2: Send to topic
    console.log("📢 Approach 2: Sending to topic...");
    try {
      const topicPayload = {
        notification: {
          title: "Topic Test",
          body: "Testing topic notifications"
        },
        data: {
          test: "topic"
        }
      };
      
      const topicResult = await messaging.sendToTopic("test_topic", topicPayload);
      console.log("✅ Topic message sent successfully:", topicResult);
    } catch (topicError) {
      console.log("❌ Topic error:", topicError.code, topicError.message);
    }
    
    // Approach 3: Send to condition
    console.log("🎯 Approach 3: Sending to condition...");
    try {
      const conditionPayload = {
        notification: {
          title: "Condition Test",
          body: "Testing condition notifications"
        },
        data: {
          test: "condition"
        }
      };
      
      const conditionResult = await messaging.sendToCondition("'test_topic' in topics", conditionPayload);
      console.log("✅ Condition message sent successfully:", conditionResult);
    } catch (conditionError) {
      console.log("❌ Condition error:", conditionError.code, conditionError.message);
    }
    
    // Test 3: Check if it's a project-specific issue
    console.log("\n✅ Test 3: Checking project configuration...");
    const projectId = admin.app().options.projectId;
    console.log("✅ Current project ID:", projectId);
    console.log("✅ Service account project:", serviceAccount.project_id);
    console.log("✅ Projects match:", projectId === serviceAccount.project_id);
    
    // Test 4: Try a minimal payload
    console.log("\n✅ Test 4: Testing minimal payload...");
    try {
      const minimalPayload = {
        data: {
          message: "Minimal test"
        }
      };
      
      const minimalResult = await messaging.sendToTopic("minimal_test", minimalPayload);
      console.log("✅ Minimal payload sent successfully:", minimalResult);
    } catch (minimalError) {
      console.log("❌ Minimal payload error:", minimalError.code, minimalError.message);
    }
    
    console.log("\n🎉 Comprehensive test completed!");
    console.log("💡 Analysis:");
    console.log("   - If all approaches give 404: FCM API access issue");
    console.log("   - If some work but others don't: Payload or topic issue");
    console.log("   - If in-app notifications work: Core functionality is fine");
    
  } catch (error) {
    console.error("❌ Comprehensive test failed:");
    console.error("Error:", error.message);
    console.error("Full Error:", JSON.stringify(error, null, 2));
  }
}

async function runAllTests() {
  console.log('🚀 Starting all notification tests...\n');
  
  await testLocalNotification();
  console.log('');
  
  await testTopicNotification();
  console.log('');
  
  await testIndividualNotification();
  console.log('');
  
  await testBloodRequestNotification();
  console.log('');
  
  console.log('🎉 All tests completed!');
  process.exit(0);
}

// Run the tests
runAllTests().catch(console.error);

// Run the comprehensive test
testNotificationsComprehensive()
  .then(() => {
    console.log("\n🎉 Test completed");
    process.exit(0);
  })
  .catch((error) => {
    console.error("💥 Test failed:", error);
    process.exit(1);
  }); 