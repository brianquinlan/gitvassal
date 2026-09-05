# GitVassal - TaskVassal

GitVassal is a serverless GitHub issue prioritization and developer task tracking platform combining **Firebase Cloud Functions (Python v2)**, **Cloud Firestore**, **Pydantic AI**, and a cross-platform **Flutter Web/Desktop/Mobile Client (TaskVassal)**.

---

## 📁 Repository Structure

```
gitvassal/
├── .firebaserc                     # Firebase project configuration (gitvassal)
├── firebase.json                   # Root Firebase configuration for Functions, Firestore, Hosting & Emulators
├── firestore.rules                 # Cloud Firestore security rules
├── firestore.indexes.json          # Firestore composite indexes
├── github-task-updater/            # Backend Firebase Cloud Functions & test suite
│   ├── functions/
│   │   ├── main.py                 # Cloud Functions (Callable, Task Queue, Firestore triggers)
│   │   ├── task.py                 # Task model & Firestore operations
│   │   ├── user.py                 # User profile schema
│   │   ├── github_sync.py          # PyGithub pagination & issue synchronization
│   │   ├── genai_ranker.py         # Pydantic AI task ranker with Gemini
│   │   └── requirements.txt        # Backend dependencies
│   ├── pyproject.toml              # Hatch / Ruff / Pyright configuration
│   └── test_*.py                   # Backend unit and integration tests
└── frontend/                       # Flutter Application (TaskVassal)
    ├── lib/
    │   ├── main.dart               # App entrypoint, emulator detection, Auth Gate
    │   ├── firebase_options.dart   # Multiplatform Firebase options for project gitvassal
    │   ├── models/                 # TaskModel and UserSettingsModel
    │   ├── services/               # AuthService (Google, GitHub, Emulator) & FirestoreService
    │   └── ui/                     # Theme, widgets (AppHeader, TaskTable, TaskRow, SettingsDialog)
    └── pubspec.yaml                # Flutter dependencies
```

---

## 🚀 Local Development

### 1. Start Firebase Emulators
Start the local Firebase Emulator Suite (Auth, Firestore, Functions, Hosting):

```bash
firebase emulators:start
```

- **Auth Emulator**: `http://127.0.0.1:9099`
- **Firestore Emulator**: `http://127.0.0.1:8080`
- **Functions Emulator**: `http://127.0.0.1:5001`
- **Emulator UI Suite**: `http://127.0.0.1:4000`

### 2. Run the Flutter Client Locally

```bash
cd frontend
flutter run -d chrome
```

The Flutter app automatically connects to local Firebase Emulators (`127.0.0.1:9099` and `127.0.0.1:8080`) during debug mode.

---

## 🧪 Verification & Testing

### Backend Checks (Python)
```bash
cd github-task-updater
.\functions\venv\Scripts\ruff.exe check .
.\functions\venv\Scripts\pyright.exe
.\functions\venv\Scripts\python.exe -m unittest discover -s . -p "test_*.py"
```

### Frontend Checks (Flutter)
```bash
cd frontend
flutter analyze
flutter test
flutter build web --release
```

---

## 🚢 Deployment

Deploy to GCP project `gitvassal`:

1. Build the Flutter Web client:
   ```bash
   cd frontend
   flutter build web --release
   cd ..
   ```

2. Deploy all Firebase components:
   ```bash
   firebase deploy
   ```
   Or deploy specific targets:
   ```bash
   firebase deploy --only functions,firestore,hosting
   ```
