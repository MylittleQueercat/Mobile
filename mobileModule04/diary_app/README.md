# Daybook

Piscine Mobile Module 04 diary app. Sign in with Google or GitHub, choose a mood,
and save dated entries to your private Cloud Firestore account. Search your entries
and revisit or delete saved memories.

## Firebase setup

Create a Firebase project and register an Android app with package ID
`com.example.diary_app`. Enable Google and GitHub under **Authentication → Sign-in
method**, configure the GitHub OAuth callback shown by Firebase, and create a
Cloud Firestore database. Add your Firebase Android configuration at
`android/app/google-services.json` (see `.gitignore`).

Use Firestore rules that restrict each account to its own entries:

```text
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid}/entries/{entryId} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

## Run on the Android emulator

Start the development environment and emulator in one terminal:

```bash
source /home/hguo/sgoinfre/hguo/mobile-dev/env.sh
emulator -avd Pixel_10 -gpu host -feature -Vulkan
```

In another terminal, run the app:

```bash
source /home/hguo/sgoinfre/hguo/mobile-dev/env.sh
cd /sgoinfre/goinfre/Perso/hguo/hguo/MobileRepo/mobileModule04/diary_app
JAVA_HOME=/home/hguo/sgoinfre/hguo/mobile-dev/gradle-cache/jdks/eclipse_adoptium-17-amd64-linux.2 \
  /home/hguo/sgoinfre/hguo/mobile-dev/tmp/flutter/bin/flutter run
```
