// Firebase web config for project stashbar-a2455.
// Find these in Firebase console → Project settings → General → Your apps → (Web app) → SDK setup and configuration.
// These values are public identifiers, not secrets; Firestore security rules protect the data.
export const firebaseConfig = {
  apiKey: 'AIzaSyCg6Pt2w706WGGkBJHxYqms7SVcTh-jEMA',
  authDomain: 'stashbar-a2455.firebaseapp.com',
  projectId: 'stashbar-a2455',
  messagingSenderId: '229303444223',
  appId: '1:229303444223:web:afcb1c9afb4e5b2cb7a2ca',
};

export const isConfigured = !firebaseConfig.apiKey.startsWith('FIREBASE_');
