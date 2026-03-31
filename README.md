# 📚 Study Planner App

A modern Flutter-based study planner that converts YouTube playlists into structured learning roadmaps with progress tracking and authentication.

---

## 🚀 Features

* 🔐 Firebase Authentication (Login & Signup)
* 📧 Email Verification System (secure login)
* 🎥 Convert YouTube playlists into study roadmaps
* ✅ Checkbox-based progress tracking
* 📊 Live progress percentage tracking
* ☁️ Cloud storage using Firebase Firestore
* 🔄 Persistent data (no data loss after logout)
* 📱 Clean and scalable UI

---

## 🧠 How It Works

1. User signs up and verifies email
2. Logs into the app
3. Creates a roadmap using a YouTube playlist link
4. App extracts video titles
5. Tracks progress using checkboxes
6. Saves everything in Firestore

---

## 🏗️ Tech Stack

* Flutter (Frontend)
* Firebase Authentication
* Firebase Firestore
* YouTube Data API v3

---

## 📂 Project Structure

lib/
├── main.dart
├── screens/
│   ├── login_screen
│   ├── signup_screen
│   ├── home_screen
│   └── roadmap_detail_screen

---

## 🔧 Setup Instructions

1. Clone the repository:

```
git clone https://github.com/your-username/study_planner.git
```

2. Navigate to the project:

```
cd study_planner
```

3. Install dependencies:

```
flutter pub get
```

4. Run the app:

```
flutter run
```

---

## ⚠️ Important Notes

* Add your own Firebase configuration
* Enable:

  * Email/Password Authentication
  * Firestore Database
* Add your YouTube API key in the code

---

## 🌟 Future Improvements

* 🏆 Streak system & gamification
* 📅 Daily study goals
* 📈 Advanced analytics
* 🎨 UI/UX enhancements
* 📱 Mobile optimization

---

## 🤝 Contribution

Feel free to fork and improve the project!

---

## 📌 Author

Harsh Jha

---

## ⭐ If you like this project

Give it a star on GitHub ⭐
