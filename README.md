<div align="center">

# 🔐 Evalock

### Presentation Evaluation & Management System

A comprehensive Flutter application for managing presentations, evaluations, and user authentication with a modern Material Design interface.

[![Flutter](https://img.shields.io/badge/Flutter-3.10+-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.10+-0175C2?style=for-the-badge&logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android-blue?style=for-the-badge)](https://flutter.dev)

---

<p align="center">
  <a href="#features">Features</a> •
  <a href="#tech-stack">Tech Stack</a> •
  <a href="#getting-started">Getting Started</a> •
  <a href="#project-structure">Project Structure</a> •
  <a href="#contributing">Contributing</a> •
  <a href="#license">License</a>
</p>

</div>

---

## 📱 About Evalock

Evalock is a comprehensive Flutter-based mobile application designed for managing presentations and evaluations. It provides a complete system for users to create, manage, and evaluate presentations with built-in authentication, database storage, and modern UI components.

## ✨ Features

### Core Features
- 🔐 **User Authentication** - Secure login and signup system with role-based access
- 📊 **Admin Dashboard** - Comprehensive admin panel for managing users and content
- 📝 **Presentation Management** - Create, edit, and organize presentations
- 📈 **Evaluation System** - Built-in evaluation tools with scoring and feedback
- 👤 **User Profiles** - Customizable user profiles with presentation history
- 📊 **Statistics & Analytics** - View presentation statistics and performance metrics

### Additional Features
- 📱 **Cross-Platform** - Works on both iOS and Android
- 🔔 **Push Notifications** - OneSignal integration for notifications
- 📄 **PDF Generation** - Export presentations and evaluations to PDF
- 💾 **Offline Storage** - Local SQLite database for offline access
- 🎨 **Material Design 3** - Modern, responsive UI design

## 🛠 Tech Stack

| Category | Technology |
|----------|------------|
| **Framework** | Flutter 3.10+ |
| **Language** | Dart 3.10+ |
| **Database** | SQLite (sqflite) |
| **State Management** | Flutter Built-in |
| **Notifications** | OneSignal |
| **PDF** | pdf, printing packages |
| **HTTP** | http package |
| **Storage** | SharedPreferences |

### Key Dependencies
```
yaml
dependencies:
  flutter:
    sdk: flutter
  sqflite: ^2.3.0
  shared_preferences: ^2.2.0
  http: ^1.2.0
  url_launcher: ^6.1.14
  image_picker: ^1.2.1
  pdf: ^3.10.0
  printing: ^5.11.0
  file_picker: ^8.0.0
  onesignal_flutter: ^5.0.0
```

## 🚀 Getting Started

### Prerequisites

Before running this project, ensure you have the following installed:

- **Flutter SDK** (3.10 or higher)
- **Dart SDK** (3.10 or higher)
- **Android SDK** (for Android development)
- **Xcode** (for iOS development, macOS only)

### Installation

1. **Clone the repository**
   
```
bash
   git clone https://github.com/khpzrnv44x-glitch/Evalock-FINAL.git
   cd Evalock-FINAL
   
```

2. **Install dependencies**
   
```
bash
   flutter pub get
   
```

3. **Run the app**
   
```
bash
   flutter run
   
```

### Building for Production

#### Android (APK)
```
bash
flutter build apk --release
```

#### iOS
```
bash
flutter build ios --release
```

## 📂 Project Structure

```
evalock/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── db/
│   │   └── database_helper.dart  # SQLite database operations
│   ├── models/
│   │   ├── data_models.dart      # Data models
│   │   └── user_model.dart      # User model
│   └── screens/
│       ├── admin_dashboard.dart      # Admin dashboard
│       ├── contact_screen.dart       # Contact page
│       ├── create_presentation_screen.dart  # Create presentation
│       ├── developer_screen.dart     # Developer info
│       ├── evaluation_screen.dart    # Evaluation page
│       ├── login_screen.dart        # Login page
│       ├── preparation_screen.dart  # Preparation page
│       ├── presentation_list.dart   # Presentation list
│       ├── presentation_stats_screen.dart  # Statistics
│       ├── profile_screen.dart      # User profile
│       ├── repository_screen.dart   # Repository page
│       └── signup_screen.dart       # Signup page
├── android/                       # Android configuration
├── ios/                          # iOS configuration
├── assets/
│   └── icon/
│       └── app_icon.png          # App icon
├── pubspec.yaml                  # Dependencies
└── README.md                     # This file
```

## 🎯 Usage

### User Roles

1. **Regular Users**
   - Create and manage presentations
   - Evaluate other presentations
   - View personal statistics
   - Update profile

2. **Administrators**
   - Full access to all features
   - User management
   - Content moderation
   - View all statistics

### Key Screens

| Screen | Description |
|--------|-------------|
| Login/Signup | Authentication screens |
| Admin Dashboard | Overview and management |
| Presentation List | Browse all presentations |
| Create Presentation | Add new presentations |
| Evaluation | Rate and evaluate presentations |
| Profile | User settings and history |
| Statistics | Performance analytics |

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👨‍💻 Developer

**Developed with ❤️**

- GitHub: [khpzrnv44x](https://github.com/khpzrnv44x-glitch)

---

<p align="center">
  Made with Flutter
</p>
