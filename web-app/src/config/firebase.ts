import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';

// Firebase yapılandırması
// Web uygulaması için Firebase Console'dan yeni bir web app ekleyip appId'yi güncelleyin
const firebaseConfig = {
  apiKey: "AIzaSyDouH4_UpJ2EDbWsmwZtkrUGsQ-7mO1V5k",
  authDomain: "maslakfilm-f479b.firebaseapp.com",
  projectId: "maslakfilm-f479b",
  storageBucket: "maslakfilm-f479b.firebasestorage.app",
  messagingSenderId: "722338354655",
  appId: "1:722338354655:web:61c2eabb44067dea83a06a"
};

let app;
let auth;
let db;

try {
  // Firebase'i başlat
  app = initializeApp(firebaseConfig);
  auth = getAuth(app);
  db = getFirestore(app);
  console.log('Firebase initialized successfully');
} catch (error: any) {
  console.error('Firebase initialization error:', error);
  
  // Eğer app zaten varsa, onu kullan
  try {
    app = initializeApp(firebaseConfig, 'maslakfilm-web');
    auth = getAuth(app);
    db = getFirestore(app);
    console.log('Firebase initialized with fallback name');
  } catch (fallbackError: any) {
    console.error('Firebase fallback initialization error:', fallbackError);
    // Son çare: mevcut app'i al
    try {
      app = initializeApp(firebaseConfig);
      auth = getAuth(app);
      db = getFirestore(app);
    } catch (finalError) {
      console.error('Firebase final initialization error:', finalError);
      throw new Error('Firebase could not be initialized. Please check your configuration.');
    }
  }
}

export { auth, db };
export default app;

