// Debug yardımcı fonksiyonları

export const logError = (error: any, context?: string) => {
  console.error(`[${context || 'App'}] Error:`, error);
  if (error.stack) {
    console.error('Stack trace:', error.stack);
  }
};

export const checkFirebaseConnection = async () => {
  try {
    const { auth } = await import('../config/firebase');
    const user = auth.currentUser;
    console.log('Firebase connection check:', {
      authInitialized: !!auth,
      currentUser: user ? user.email : 'No user',
    });
    return true;
  } catch (error) {
    logError(error, 'Firebase Connection Check');
    return false;
  }
};

