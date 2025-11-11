import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App.tsx'
import ErrorBoundary from './components/ErrorBoundary'
import './index.css'

// Debug: Check if root element exists
const rootElement = document.getElementById('root');

if (!rootElement) {
  console.error('Root element (#root) not found in HTML');
  document.body.innerHTML = '<div style="padding: 20px; font-family: Arial;"><h1>Hata: Root element bulunamadı</h1><p>HTML dosyasında &lt;div id="root"&gt;&lt;/div&gt; elementi olmalı.</p></div>';
  throw new Error('Root element not found');
}

console.log('React app starting...');

try {
  ReactDOM.createRoot(rootElement).render(
    <React.StrictMode>
      <ErrorBoundary>
        <App />
      </ErrorBoundary>
    </React.StrictMode>,
  );
  console.log('React app rendered successfully');
} catch (error) {
  console.error('Error rendering React app:', error);
  rootElement.innerHTML = `
    <div style="padding: 20px; font-family: Arial; text-align: center;">
      <h1 style="color: red;">Uygulama Yüklenirken Hata Oluştu</h1>
      <p>${error instanceof Error ? error.message : 'Bilinmeyen hata'}</p>
      <button onclick="window.location.reload()" style="padding: 10px 20px; margin-top: 20px; cursor: pointer;">
        Sayfayı Yenile
      </button>
      <details style="margin-top: 20px; text-align: left;">
        <summary>Hata Detayları</summary>
        <pre style="background: #f5f5f5; padding: 10px; overflow: auto;">${error instanceof Error ? error.stack : JSON.stringify(error, null, 2)}</pre>
      </details>
    </div>
  `;
}

