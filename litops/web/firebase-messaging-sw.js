// Give the service worker access to Firebase Messaging.
// Note that you can only use Firebase Messaging here, other Firebase libraries are not available.
importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js");

// Initialize the Firebase app in the service worker by passing in the messagingSenderId.
firebase.initializeApp({
  apiKey: "AIzaSyC8HGFhsoCUPVNZkZ4E71fkxTIgeGrGJK0",
  authDomain: "litops-99d71.firebaseapp.com",
  projectId: "litops-99d71",
  storageBucket: "litops-99d71.firebasestorage.app",
  messagingSenderId: "638788941756",
  appId: "1:638788941756:web:ca330f325717a91ed55db9"
});

// Retrieve an instance of Firebase Messaging so that it can handle background messages.
const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log("Received background message: ", payload);
  const notificationTitle = payload.notification.title || "New Notification";
  const notificationOptions = {
    body: payload.notification.body || "",
    icon: "/favicon.png"
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});
