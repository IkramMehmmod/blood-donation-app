const { exec } = require('child_process');
const { promisify } = require('util');
const execAsync = promisify(exec);

// Deploy Firebase Functions
async function deployFunctions() {
  console.log("🚀 Deploying Firebase Functions...");
  
  try {
    const { stdout, stderr } = await execAsync('firebase deploy --only functions');
    console.log("✅ Deployment output:", stdout);
    if (stderr) {
      console.log("⚠️ Deployment warnings:", stderr);
    }
    return true;
  } catch (error) {
    console.log("❌ Deployment failed:", error.message);
    return false;
  }
}

// Test FCM after deployment
async function testFCMAfterDeployment() {
  console.log("\n🔍 Testing FCM after deployment...");
  
  try {
    // Import the test functions
    const { runTests } = require('./test_fcm_configuration');
    await runTests();
  } catch (error) {
    console.log("❌ FCM test failed:", error.message);
  }
}

// Check Firebase project status
async function checkFirebaseStatus() {
  console.log("🔍 Checking Firebase project status...");
  
  try {
    const { stdout } = await execAsync('firebase projects:list');
    console.log("📋 Available projects:", stdout);
  } catch (error) {
    console.log("❌ Could not list projects:", error.message);
  }
}

// Main deployment and test function
async function deployAndTest() {
  console.log("🎯 Starting deployment and testing process...\n");
  
  // Check Firebase status
  await checkFirebaseStatus();
  console.log("");
  
  // Deploy functions
  const deploySuccess = await deployFunctions();
  
  if (deploySuccess) {
    console.log("\n✅ Functions deployed successfully!");
    console.log("⏳ Waiting 30 seconds for deployment to propagate...");
    
    // Wait for deployment to propagate
    await new Promise(resolve => setTimeout(resolve, 30000));
    
    // Test FCM
    await testFCMAfterDeployment();
  } else {
    console.log("\n❌ Deployment failed. Please check the errors above.");
    console.log("\n🔧 Common deployment issues:");
    console.log("1. Make sure you're logged into Firebase CLI");
    console.log("2. Check that your project is properly configured");
    console.log("3. Verify you have the necessary permissions");
    console.log("4. Ensure Firebase Core is enabled in your project");
  }
}

// Export for use in other files
module.exports = {
  deployFunctions,
  testFCMAfterDeployment,
  checkFirebaseStatus,
  deployAndTest
};

// Run if this file is executed directly
if (require.main === module) {
  deployAndTest();
} 