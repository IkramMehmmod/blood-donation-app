# Blood Donation App

A comprehensive Flutter application designed to connect blood donors and recipients, featuring Firebase integration for authentication, real-time notifications, and secure data management.

## 🩸 Project Overview

This project consists of a Flutter mobile application with Firebase backend services, designed to facilitate blood donation requests and connect donors with those in need.

## 📱 Features

- **User Authentication**: Secure login and registration with Firebase Auth
- **Blood Donation Management**: Request and manage blood donations
- **Real-time Notifications**: Push notifications for donation requests and updates
- **User Profiles**: Comprehensive donor and recipient profiles
- **Health Tracking**: Monitor donor health information
- **Location Services**: Google Maps integration for finding nearby donors
- **Cross-platform**: Works on Android and iOS devices

## 🏗️ Project Structure

```
blood-donation-app/
├── blood_donation_app/          # Main Flutter application
│   ├── lib/                     # Dart source code
│   │   ├── models/             # Data models
│   │   ├── screens/            # UI screens
│   │   ├── services/           # Business logic & Firebase services
│   │   ├── widgets/            # Reusable UI components
│   │   └── theme/              # App theming
│   ├── assets/                 # Images, fonts, screenshots
│   └── android/ios/            # Platform-specific code
├── functions/                   # Firebase Cloud Functions
├── firebase.json               # Firebase configuration
└── firestore.rules             # Firestore security rules
```

## 🚀 Quick Start

### Prerequisites
- Flutter SDK (latest stable version)
- Firebase project setup
- Android Studio / Xcode for mobile development

### Installation
1. **Clone the repository:**
   ```bash
   git clone https://github.com/IkramMehmmod/blood-donation-app.git
   cd blood-donation-app
   ```

2. **Navigate to the Flutter app:**
   ```bash
   cd blood_donation_app
   ```

3. **Install dependencies:**
   ```bash
   flutter pub get
   ```

4. **Setup Firebase:**
   - Add your `google-services.json` to `android/app/`
   - Add your `GoogleService-Info.plist` to `ios/Runner/`
   - Configure Firebase project settings

5. **Run the application:**
   ```bash
   flutter run
   ```

## 📸 Screenshots

See the [Flutter App README](blood_donation_app/README.md) for detailed screenshots of the application.

## 🔧 Technologies Used

- **Frontend**: Flutter, Dart
- **Backend**: Firebase (Auth, Firestore, Cloud Functions, FCM)
- **Maps**: Google Maps API
- **Notifications**: Firebase Cloud Messaging

## 📋 Requirements

- Flutter 3.0+
- Dart 2.17+
- Firebase project
- Google Maps API key

## 🤝 Contributing

This is a private repository. For collaboration or contributions, please contact the repository owner.

## 📄 License

This project is private. All rights reserved.

## 📞 Support

For support or questions, please open an issue in this repository or contact the development team.

---

**Note**: This repository contains sensitive Firebase configuration files. Please ensure proper security measures when deploying or sharing this code. 