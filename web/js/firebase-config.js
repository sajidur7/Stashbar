// Firebase web config for project stashbar-a2455.
// Find these in Firebase console → Project settings → General → Your apps → (Web app) → SDK setup and configuration.
// These values are public identifiers, not secrets; Firestore security rules protect the data.
export const firebaseConfig = {
  apiKey: 'FIREBASE_API_KEY',
  authDomain: 'stashbar-a2455.firebaseapp.com',
  projectId: 'stashbar-a2455',
  appId: 'FIREBASE_APP_ID',
};

export const isConfigured = !firebaseConfig.apiKey.startsWith('FIREBASE_');
