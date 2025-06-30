const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json'); // Update path if needed

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function deleteAllDocumentsInCollection(collectionPath) {
  const collectionRef = db.collection(collectionPath);
  let snapshot = await collectionRef.get();

  while (!snapshot.empty) {
    const batch = db.batch();
    snapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    await batch.commit();
    console.log(`Deleted ${snapshot.size} documents from ${collectionPath}`);
    snapshot = await collectionRef.get();
  }
}

async function deleteAllCollections() {
  const collections = await db.listCollections();
  for (const collection of collections) {
    console.log(`Deleting all documents in collection: ${collection.id}`);
    await deleteAllDocumentsInCollection(collection.id);
  }
  console.log('✅ All documents deleted from all collections.');
}

deleteAllCollections().catch(error => {
  console.error('Error deleting documents:', error);
}); 