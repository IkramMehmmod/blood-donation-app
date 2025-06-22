const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");

// Initialize Firebase Admin with explicit service account
// In production, this will use the default service account automatically
// For local development, you can specify the service account path
let serviceAccount;
try {
  // Try to load service account from environment or default location
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    serviceAccount = require(process.env.GOOGLE_APPLICATION_CREDENTIALS);
  }
} catch (error) {
  logger.warn("Service account not found, using default credentials");
}

// Initialize Firebase Admin
if (serviceAccount) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: "https://bloodbridge-4a327-default-rtdb.firebaseio.com"
  });
} else {
  // Use default credentials (recommended for production)
  admin.initializeApp();
}

// Get Firestore instance
const firestore = admin.firestore();

// Android notification channel ID (must match Flutter app)
const ANDROID_CHANNEL_ID = "blood_donation_high_importance";

/**
 * Send notification when a new blood request is created
 * Using MINIMAL FCM payload structure for Firebase Admin SDK
 */
exports.sendBloodRequestNotification = onDocumentCreated(
    "requests/{requestId}",
    async (event) => {
      try {
        const requestData = event.data.data();
        const requestId = event.params.requestId;

        logger.log(`🔔 Processing blood request notification for request: ${requestId}`);
        logger.log(`📋 Request data:`, JSON.stringify(requestData, null, 2));

        // Only send notifications for 'open' requests
        if (requestData.status !== "open") {
          logger.log(`❌ Blood request ${requestId} is not 'open'. Status: ${requestData.status}. No notification sent.`);
          return null;
        }

        logger.log(`✅ Request is 'open'. Proceeding with notification...`);

        // Extract request data
        const bloodGroup = requestData.bloodGroup;
        const urgency = requestData.urgency || "normal";
        const location = requestData.location || "an unspecified location";
        const requesterId = requestData.requesterId;
        const patientName = requestData.patientName || "a patient";
        const hospital = requestData.hospital || location;

        logger.log(`🩸 Blood Group: ${bloodGroup}`);
        logger.log(`🚨 Urgency: ${urgency}`);
        logger.log(`📍 Location: ${location}`);
        logger.log(`👤 Requester ID: ${requesterId}`);

        const urgencyText = urgency === "urgent" ? "URGENT: " : "";

        // ✅ MINIMAL: Only essential FCM payload fields
        const notificationPayload = {
          notification: {
            title: `${urgencyText}New Blood Request: ${bloodGroup}`,
            body: `${patientName} in ${hospital} needs ${bloodGroup} blood. Can you help?`,
          },
          data: {
            type: "blood_request",
            referenceId: requestId,
            bloodGroup: bloodGroup,
            location: location,
            urgency: urgency,
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            channelId: ANDROID_CHANNEL_ID,
          },
        };

        logger.log(`📤 Sending notification payload:`, JSON.stringify(notificationPayload, null, 2));

        // Try sending to topic with better error handling
        try {
          logger.log(`🔔 Attempting to send to topic: new_requests`);
          await admin.messaging().sendToTopic("new_requests", notificationPayload);
          logger.log("✅ Notification sent to topic: new_requests");
        } catch (topicError) {
          logger.error("❌ Error sending to topic 'new_requests':", topicError);
          logger.error("❌ Error details:", JSON.stringify(topicError, null, 2));
          logger.log("💡 This is expected if no devices have subscribed to this topic yet");
        }

        // Try sending to blood group specific topic
        try {
          const formattedBloodGroup = bloodGroup
              .replace("+", "pos")
              .replace("-", "neg");
          const bloodGroupTopic = `blood_${formattedBloodGroup.toLowerCase()}`;

          logger.log(`🔔 Attempting to send to topic: ${bloodGroupTopic}`);
          await admin.messaging().sendToTopic(bloodGroupTopic, notificationPayload);
          logger.log(`✅ Notification sent to topic: ${bloodGroupTopic}`);
        } catch (bloodGroupError) {
          logger.error("❌ Error sending to blood group topic:", bloodGroupError);
          logger.error("❌ Error details:", JSON.stringify(bloodGroupError, null, 2));
          logger.log("💡 This is expected if no devices have subscribed to this topic yet");
        }

        // Create in-app notifications for all users (THIS IS THE MAIN FEATURE)
        try {
          const usersSnapshot = await firestore.collection("users").get();
          logger.log(`👥 Found ${usersSnapshot.size} users in database`);

          if (!usersSnapshot.empty) {
            const notificationPromises = [];
            let skippedCount = 0;
            
            usersSnapshot.forEach((doc) => {
              const userId = doc.id;
              // Skip the requester
              if (userId === requesterId) {
                skippedCount++;
                return;
              }

              notificationPromises.push(
                  firestore.collection("notifications").add({
                    userId: userId,
                    title: notificationPayload.notification.title,
                    message: notificationPayload.notification.body,
                    type: "blood_request",
                    referenceId: requestId,
                    isRead: false,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                  }),
              );
            });

            await Promise.all(notificationPromises);
            logger.log(`✅ Created ${notificationPromises.length} in-app notification records`);
            logger.log(`⏭️ Skipped ${skippedCount} notifications (requester)`);
            logger.log(`🎉 In-app notifications are working perfectly!`);
          }
        } catch (inAppError) {
          logger.error("❌ Error creating in-app notifications:", inAppError);
        }

        logger.log(`🎉 Blood request notification process completed for request ${requestId}`);
        logger.log(`💡 In-app notifications are the primary notification method`);
        logger.log(`💡 FCM push notifications will work once devices subscribe to topics`);
      } catch (error) {
        logger.error("❌ Error sending blood request notification:", error);
      }

      return null;
    },
);

/**
 * Send notification when a blood request status changes
 * Using MINIMAL FCM payload structure
 */
exports.sendRequestActionNotification = onDocumentUpdated(
    "requests/{requestId}",
    async (event) => {
      try {
        const oldData = event.data.before.data();
        const newData = event.data.after.data();
        const requestId = event.params.requestId;

        // Check if status changed
        if (newData.status === oldData.status) {
          return null;
        }

        const requesterId = newData.requesterId;
        const bloodGroup = newData.bloodGroup;
        const patientName = newData.patientName || "a patient";
        const responders = newData.responders || [];
        const acceptorId = responders.length > 0 ? responders[responders.length - 1] : null;

        let notificationTitle = "";
        let notificationBody = "";
        let notificationType = "";
        const targetUserIds = [];

        switch (newData.status) {
          case "accepted":
            notificationTitle = "✅ Request Accepted!";
            notificationBody = `Your blood request for ${patientName} (${bloodGroup}) has been accepted by a donor.`;
            notificationType = "request_accepted";
            targetUserIds.push(requesterId);
            if (acceptorId) {
              targetUserIds.push(acceptorId);
            }
            break;
          case "completed":
            notificationTitle = "💖 Donation Completed!";
            notificationBody = `The blood donation for ${patientName} (${bloodGroup}) has been completed. Thank you for saving a life!`;
            notificationType = "donation_completed";
            targetUserIds.push(requesterId);
            if (acceptorId) {
              targetUserIds.push(acceptorId);
            }
            break;
          case "cancelled":
          case "closed":
            notificationTitle = "🚫 Request Closed";
            notificationBody = `The blood request for ${patientName} (${bloodGroup}) has been closed.`;
            notificationType = "request_cancelled";
            targetUserIds.push(requesterId);
            if (acceptorId) {
              targetUserIds.push(acceptorId);
            }
            break;
          default:
            return null;
        }

        const uniqueTargetUserIds = [...new Set(targetUserIds)].filter((id) => id);

        if (uniqueTargetUserIds.length === 0) {
          return null;
        }

        // Get FCM tokens for target users
        const fcmTokensToNotify = [];
        for (const userId of uniqueTargetUserIds) {
          try {
            const userDoc = await firestore.collection("users").doc(userId).get();
            if (userDoc.exists) {
              const userData = userDoc.data();
              if (userData.fcmToken) {
                fcmTokensToNotify.push(userData.fcmToken);
              }
            }
          } catch (error) {
            logger.error(`Error fetching FCM token for user ${userId}:`, error);
          }
        }

        // ✅ MINIMAL: Only essential FCM payload fields
        const notificationPayload = {
          notification: {
            title: notificationTitle,
            body: notificationBody,
          },
          data: {
            type: notificationType,
            referenceId: requestId,
            status: newData.status,
            bloodGroup: bloodGroup,
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            channelId: ANDROID_CHANNEL_ID,
          },
        };

        // Send FCM notifications
        if (fcmTokensToNotify.length > 0) {
          const messages = fcmTokensToNotify.map((token) => ({
            token: token,
            ...notificationPayload,
          }));

          const fcmResult = await admin.messaging().sendAll(messages);
          logger.log(`✅ Sent action notifications to ${fcmTokensToNotify.length} devices. Success: ${fcmResult.successCount}, Failure: ${fcmResult.failureCount}`);
        }

        // Create in-app notifications
        const inAppNotificationPromises = uniqueTargetUserIds.map((userId) =>
          firestore.collection("notifications").add({
            userId: userId,
            title: notificationTitle,
            message: notificationBody,
            type: notificationType,
            referenceId: requestId,
            isRead: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          }),
        );

        await Promise.all(inAppNotificationPromises);
        logger.log(`✅ Created ${inAppNotificationPromises.length} in-app notification records`);

        logger.log(`✅ Request action notification sent successfully for request ${requestId}`);
      } catch (error) {
        logger.error("❌ Error sending action notifications:", error);
      }

      return null;
    },
);

/**
 * Test function to verify FCM is working
 * Using MINIMAL FCM payload structure
 */
exports.testFCMNotification = onDocumentCreated(
    "test_fcm/{testId}",
    async (event) => {
      try {
        logger.log("Testing FCM notification...");

        // ✅ MINIMAL: Only essential FCM payload fields
        const testPayload = {
          notification: {
            title: "🧪 Test FCM Notification",
            body: "This is a test notification to verify FCM is working!",
          },
          data: {
            type: "test",
            referenceId: "test123",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            channelId: ANDROID_CHANNEL_ID,
          },
        };

        // Send to topic
        await admin.messaging().sendToTopic("new_requests", testPayload);
        logger.log("✅ Test FCM notification sent to topic: new_requests");

        // Send to all users via individual tokens
        const usersSnapshot = await firestore.collection("users").get();
        if (!usersSnapshot.empty) {
          const fcmTokens = [];
          usersSnapshot.forEach((doc) => {
            const userData = doc.data();
            if (userData.fcmToken) {
              fcmTokens.push(userData.fcmToken);
            }
          });

          if (fcmTokens.length > 0) {
            const messages = fcmTokens.map((token) => ({
              token: token,
              ...testPayload,
            }));

            const result = await admin.messaging().sendAll(messages);
            logger.log(`✅ Test FCM notifications sent to ${fcmTokens.length} devices. Success: ${result.successCount}, Failure: ${result.failureCount}`);
          }
        }

        return null;
      } catch (error) {
        logger.error("❌ Error in test FCM notification:", error);
        return null;
      }
    },
);

/**
 * Test function for individual user notifications
 * Using MINIMAL FCM payload structure
 */
exports.sendTestNotification = onDocumentCreated(
    "test_notifications/{testId}",
    async (event) => {
      try {
        const testData = event.data.data();
        const userId = testData.userId;

        if (!userId) {
          logger.error("No userId provided in test notification");
          return null;
        }

        // Get user's FCM token
        const userDoc = await firestore.collection("users").doc(userId).get();
        if (!userDoc.exists || !userDoc.data().fcmToken) {
          logger.error(`No FCM token found for user ${userId}`);
          return null;
        }

        const fcmToken = userDoc.data().fcmToken;

        // ✅ MINIMAL: Only essential FCM payload fields
        const testNotificationPayload = {
          token: fcmToken,
          notification: {
            title: "🧪 Test Notification",
            body: "This is a test notification from Firebase Functions!",
          },
          data: {
            type: "test",
            referenceId: "test123",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            channelId: ANDROID_CHANNEL_ID,
          },
        };

        await admin.messaging().send(testNotificationPayload);
        logger.log(`✅ Test notification sent to user ${userId}`);

        // Create in-app notification
        await firestore.collection("notifications").add({
          userId: userId,
          title: "🧪 Test Notification",
          message: "This is a test notification from Firebase Functions!",
          type: "test",
          referenceId: "test123",
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        logger.log(`✅ Test in-app notification created for user ${userId}`);
      } catch (error) {
        logger.error("❌ Error sending test notification:", error);
      }

      return null;
    },
);

/**
 * Cleanup expired blood requests every 24 hours
 * Automatically closes requests that have passed their required date
 */
exports.cleanupExpiredRequests = onSchedule(
    {
      region: "asia-south1",
      schedule: "every 24 hours",
      timeZone: "UTC",
    },
    async (event) => {
      try {
        const now = admin.firestore.Timestamp.now();
        const requestsToCloseSnapshot = await firestore
            .collection("requests")
            .where("status", "==", "open")
            .where("requiredDate", "<", now)
            .get();

        if (requestsToCloseSnapshot.empty) {
          logger.log("No expired blood requests found to close.");
          return null;
        }

        const batch = firestore.batch();
        let count = 0;

        requestsToCloseSnapshot.forEach((doc) => {
          batch.update(doc.ref, {
            status: "closed",
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
          });
          count++;
        });

        if (count > 0) {
          await batch.commit();
          logger.log(`Closed ${count} expired blood requests.`);
        }

        return null;
      } catch (error) {
        logger.error("Error cleaning up expired requests:", error);
        return null;
      }
    },
);
