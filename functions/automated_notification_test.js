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

// Helper: returns true if lastDonation is more than 3 months ago
function isEligible(lastDonation) {
  if (!lastDonation) return true;
  const now = new Date();
  const threeMonthsAgo = new Date(now.getFullYear(), now.getMonth() - 3, now.getDate());
  return lastDonation.toDate() < threeMonthsAgo;
}

async function main() {
  console.log("\n=== Automated Notification & Eligibility Test ===\n");

  // 1. Create test users with different lastDonation dates
  const now = new Date();
  const users = [
    { name: "EligibleUser", lastDonation: null },
    { name: "JustEligibleUser", lastDonation: Timestamp.fromDate(new Date(now.getFullYear(), now.getMonth() - 3, now.getDate() - 1)) },
    { name: "IneligibleUser", lastDonation: Timestamp.fromDate(new Date(now.getFullYear(), now.getMonth() - 2, now.getDate())) },
  ];

  // 2. Create users in Firestore
  const userIds = [];
  for (const user of users) {
    const docRef = await firestore.collection("users").add({
      name: user.name,
      lastDonation: user.lastDonation,
      fcmToken: "dummy-token-" + user.name, // Not a real token, just for test
      role: "donor",
      email: user.name + "@test.com",
    });
    userIds.push(docRef.id);
    user.id = docRef.id;
    console.log(`Created user: ${user.name} (eligible: ${isEligible(user.lastDonation)})`);
  }

  // 3. Create a test blood request
  const testRequest = {
    bloodGroup: "A+",
    urgency: "normal",
    location: "Test Hospital",
    requesterId: userIds[0], // First user is requester
    patientName: "Test Patient",
    hospital: "Test Hospital",
    status: "open",
    requiredDate: Timestamp.fromDate(new Date(now.getTime() + 24 * 60 * 60 * 1000)),
    createdAt: Timestamp.now(),
    updated_at: Timestamp.now(),
    description: "Automated test blood request",
    contactNumber: "1234567890",
    units: 1
  };
  const requestRef = await firestore.collection("requests").add(testRequest);
  console.log("Created test blood request.");

  // 4. Wait for Cloud Function to process
  console.log("Waiting 5 seconds for notification function to process...");
  await new Promise(res => setTimeout(res, 5000));

  // 5. Check notifications in Firestore
  const notificationsSnapshot = await firestore.collection("notifications").where("referenceId", "==", requestRef.id).get();
  const notifiedUserIds = new Set();
  notificationsSnapshot.forEach(doc => {
    const n = doc.data();
    notifiedUserIds.add(n.userId);
  });

  // 6. Analyze results
  for (const user of users) {
    const eligible = isEligible(user.lastDonation);
    const notified = notifiedUserIds.has(user.id);
    console.log(`User: ${user.name} | Eligible: ${eligible} | Notified: ${notified}`);
  }

  // 7. Clean up test data
  await requestRef.delete();
  for (const userId of userIds) {
    await firestore.collection("users").doc(userId).delete();
  }
  notificationsSnapshot.forEach(doc => doc.ref.delete());
  console.log("\nTest data cleaned up.");

  console.log("\n=== Automated Test Complete ===\n");
}

main().catch(e => {
  console.error("Test failed:", e);
  process.exit(1);
}); 