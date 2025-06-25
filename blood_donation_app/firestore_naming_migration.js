const admin = require('firebase-admin');
const serviceAccount = require('./bloodbridge-4a327-6969deca6803.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'bloodbridge-4a327'
});

const db = admin.firestore();

// List all collections you want to update
const collectionsToUpdate = [
  'users',
  'requests',
  'notifications',
  'donations',
  'healthData',
  'userSettings',
  'deviceTokens',
  'bugReports',
  'encryptionKeys'
];

// Map of snake_case to camelCase for each collection
const fieldMappings = {
  users: {
    blood_group: 'bloodGroup',
    last_donation: 'lastDonation',
    image_url: 'imageUrl',
    created_at: 'createdAt',
    updated_at: 'updatedAt',
    is_donor: 'isDonor',
    fcm_token: 'fcmToken'
  },
  requests: {
    blood_group: 'bloodGroup',
    requester_id: 'requesterId',
    requester_name: 'requesterName',
    patient_name: 'patientName',
    contact_number: 'contactNumber',
    required_date: 'requiredDate',
    additional_info: 'additionalInfo',
    created_at: 'createdAt',
    updated_at: 'updatedAt',
    units_needed: 'units'
  },
  notifications: {
    reference_id: 'referenceId',
    is_read: 'isRead',
    created_at: 'createdAt',
    user_id: 'userId'
  },
  donations: {
    blood_group: 'bloodGroup',
    user_id: 'userId',
    request_id: 'requestId',
    patient_name: 'patientName',
    created_at: 'createdAt',
    updated_at: 'updatedAt'
  },
  healthData: {
    user_id: 'userId',
    blood_pressure: 'bloodPressure',
    last_checkup: 'lastCheckup',
    medical_conditions: 'medicalConditions',
    created_at: 'createdAt',
    updated_at: 'updatedAt'
  },
  userSettings: {
    user_id: 'userId',
    dark_mode: 'darkMode',
    created_at: 'createdAt',
    updated_at: 'updatedAt'
  },
  deviceTokens: {
    user_id: 'userId',
    last_updated: 'lastUpdated'
  },
  bugReports: {
    user_id: 'userId',
    device_info: 'deviceInfo',
    app_version: 'appVersion',
    created_at: 'createdAt'
  },
  encryptionKeys: {
    created_at: 'createdAt',
    rotated_at: 'rotatedAt',
    previous_key: 'previousKey'
  }
};

async function migrateCollection(collectionName, mapping) {
  console.log(`Starting migration for collection: ${collectionName}`);
  const snapshot = await db.collection(collectionName).get();
  let updatedCount = 0;
  
  if (snapshot.empty) {
    console.log(`Collection ${collectionName} is empty, skipping...`);
    return;
  }
  
  for (const doc of snapshot.docs) {
    const data = doc.data();
    let updateNeeded = false;
    const updates = {};
    const deletes = {};

    // For each mapping, migrate value and mark for deletion if duplicate
    for (const [snake, camel] of Object.entries(mapping)) {
      if (snake in data) {
        // Only update if camelCase doesn't already exist or is different
        if (!(camel in data) || data[camel] !== data[snake]) {
          updates[camel] = data[snake];
        }
        deletes[snake] = admin.firestore.FieldValue.delete();
        updateNeeded = true;
      }
    }

    // Remove any camelCase fields that are duplicates of snake_case
    for (const [snake, camel] of Object.entries(mapping)) {
      if (snake in data && camel in data && data[snake] === data[camel]) {
        // Remove the snake_case field
        deletes[snake] = admin.firestore.FieldValue.delete();
        updateNeeded = true;
      }
    }

    if (updateNeeded) {
      try {
        await db.collection(collectionName).doc(doc.id).update({
          ...updates,
          ...deletes
        });
        updatedCount++;
        console.log(`Updated ${collectionName}/${doc.id}`);
      } catch (error) {
        console.error(`Error updating ${collectionName}/${doc.id}:`, error);
      }
    }
  }
  console.log(`Finished updating ${updatedCount} documents in ${collectionName}`);
}

async function listAllCollections() {
  console.log('Listing all collections in Firestore...');
  const collections = await db.listCollections();
  collections.forEach(collection => {
    console.log(`- ${collection.id}`);
  });
}

async function migrateBugReportsSpecific() {
  console.log('Starting specific migration for bug reports...');
  
  // Try different possible collection names
  const possibleNames = ['bugReports', 'bugreports'];
  
  for (const collectionName of possibleNames) {
    try {
      console.log(`Checking collection: ${collectionName}`);
      const snapshot = await db.collection(collectionName).get();
      
      if (!snapshot.empty) {
        console.log(`Found ${snapshot.size} documents in ${collectionName}`);
        let updatedCount = 0;
        
        for (const doc of snapshot.docs) {
          const data = doc.data();
          let updateNeeded = false;
          const updates = {};
          const deletes = {};

          // Map snake_case to camelCase for bug reports
          const bugReportMappings = {
            'user_id': 'userId',
            'created_at': 'createdAt',
            'device_info': 'deviceInfo',
            'app_version': 'appVersion'
          };

          for (const [snake, camel] of Object.entries(bugReportMappings)) {
            if (snake in data) {
              console.log(`Found snake_case field: ${snake} in document ${doc.id}`);
              // Only update if camelCase doesn't already exist or is different
              if (!(camel in data) || data[camel] !== data[snake]) {
                updates[camel] = data[snake];
              }
              deletes[snake] = admin.firestore.FieldValue.delete();
              updateNeeded = true;
            }
          }

          if (updateNeeded) {
            try {
              await db.collection(collectionName).doc(doc.id).update({
                ...updates,
                ...deletes
              });
              updatedCount++;
              console.log(`Updated ${collectionName}/${doc.id}`);
            } catch (error) {
              console.error(`Error updating ${collectionName}/${doc.id}:`, error);
            }
          }
        }
        console.log(`Finished updating ${updatedCount} documents in ${collectionName}`);
        return; // Found and processed the collection
      }
    } catch (error) {
      console.log(`Collection ${collectionName} not found or error:`, error.message);
    }
  }
  
  console.log('No bug reports collection found with any of the expected names');
}

// Helper to copy documents from old collection to new collection
async function copyCollection(oldName, newName) {
  console.log(`Copying documents from ${oldName} to ${newName}...`);
  const snapshot = await db.collection(oldName).get();
  if (snapshot.empty) {
    console.log(`No documents found in ${oldName}, skipping.`);
    return;
  }
  let copied = 0;
  for (const doc of snapshot.docs) {
    try {
      await db.collection(newName).doc(doc.id).set(doc.data(), { merge: true });
      copied++;
      console.log(`Copied ${oldName}/${doc.id} to ${newName}/${doc.id}`);
    } catch (err) {
      console.error(`Error copying ${oldName}/${doc.id}:`, err);
    }
  }
  console.log(`Copied ${copied} documents from ${oldName} to ${newName}`);
}

async function runMigration() {
  console.log('Starting Firestore field naming migration...');
  console.log('This will convert all snake_case fields to camelCase...');
  
  // First, list all collections
  await listAllCollections();
  
  // Copy old collections to new camelCase collections
  await copyCollection('health_data', 'healthData');
  await copyCollection('bug_reports', 'bugReports');
  await copyCollection('encryption_keys', 'encryptionKeys');
  
  for (const collection of collectionsToUpdate) {
    if (fieldMappings[collection]) {
      await migrateCollection(collection, fieldMappings[collection]);
    } else {
      console.log(`No field mappings found for collection: ${collection}`);
    }
  }
  
  // Run specific bug reports migration
  await migrateBugReportsSpecific();
  
  console.log('Migration complete!');
}

console.log('Migration script started');
try {
  runMigration().catch(console.error);
} catch (err) {
  console.error('Top-level error:', err);
}
