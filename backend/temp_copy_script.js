require('dotenv').config();
const admin = require('firebase-admin');

async function copyTemplates() {
  // Initialize Firebase Admin SDK from .env
  try {
    if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      throw new Error('GOOGLE_APPLICATION_CREDENTIALS is not set in .env file.');
    }
    const serviceAccount = require(process.env.GOOGLE_APPLICATION_CREDENTIALS);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    console.log('--- Firebase Admin SDK initialized successfully. ---');
  } catch (error) {
    console.error('--- CRITICAL: Firebase Admin SDK initialization failed. ---');
    console.error(error.message);
    process.exit(1);
  }

  const db = admin.firestore();

  const sourceDocId = 'mohithacky890@gmail.com';
  const destinationDocId = 'NvxDMorN6OS4wUZMSyy9aAs1V2H3';

  const sourceCollectionRef = db.collection('users').doc(sourceDocId).collection('templates');
  const destinationCollectionRef = db.collection('users').doc(destinationDocId).collection('templates');

  console.log(`Starting copy from 'users/${sourceDocId}/templates' to 'users/${destinationDocId}/templates'.`);

  try {
    const snapshot = await sourceCollectionRef.get();

    if (snapshot.empty) {
      console.log('Source collection is empty. Nothing to copy.');
      return;
    }

    let copiedCount = 0;
    const batch = db.batch();

    snapshot.forEach(doc => {
      const newDocRef = destinationCollectionRef.doc(doc.id);
      batch.set(newDocRef, doc.data());
      copiedCount++;
    });

    await batch.commit();
    console.log(`--- Success! Copied ${copiedCount} documents. ---`);

  } catch (error) {
    console.error('--- Error copying collection: ---', error);
  } finally {
    // The process will exit automatically
  }
}

copyTemplates();
