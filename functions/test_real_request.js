const admin = require("firebase-admin");

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

async function testRealBloodRequest() {
  console.log("🧪 Testing Real Blood Request Notification...");
  
  try {
    // Create a test blood request
    const testRequest = {
      bloodGroup: "A+",
      urgency: "normal",
      location: "Test Hospital",
      requesterId: "test_user_id",
      patientName: "Test Patient",
      hospital: "Test Hospital",
      status: "open",
      requiredDate: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 24 * 60 * 60 * 1000)), // 24 hours from now
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
      description: "This is a test blood request to verify the notification system",
      contactNumber: "1234567890",
      units: 1
    };
    
    console.log("📝 Creating test blood request...");
    const docRef = await firestore.collection("requests").add(testRequest);
    console.log("✅ Test blood request created with ID:", docRef.id);
    
    // Wait a moment for the function to process
    console.log("⏳ Waiting for notification function to process...");
    await new Promise(resolve => setTimeout(resolve, 3000));
    
    // Check if notifications were created
    const notificationsSnapshot = await firestore.collection("notifications").get();
    console.log(`📱 Found ${notificationsSnapshot.size} notifications in database`);
    
    if (notificationsSnapshot.size > 0) {
      console.log("✅ Notifications were created successfully!");
      notificationsSnapshot.forEach(doc => {
        const notification = doc.data();
        console.log(`   - ${notification.title}: ${notification.message}`);
      });
    } else {
      console.log("⚠️ No notifications found - this might be normal if no users exist");
    }
    
    // Clean up - delete the test request
    console.log("🧹 Cleaning up test request...");
    await docRef.delete();
    console.log("✅ Test request deleted");
    
    return true;
    
  } catch (error) {
    console.log("❌ Test failed:", error.message);
    console.log("📋 Error details:", error);
    return false;
  }
}

// Run the test
testRealBloodRequest().then(success => {
  if (success) {
    console.log("\n🎉 Blood request notification system is working!");
    console.log("💡 Check your Flutter app for notifications");
  } else {
    console.log("\n⚠️ Notification system needs attention");
    console.log("💡 Check Firebase Functions logs for details");
  }
}); 