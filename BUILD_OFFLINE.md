# =======================================================
# PANDUAN BUILD OFFLINE - gentix-apps-update.apk
# =======================================================

## Prasyarat (sudah terpenuhi ✅)
- Flutter 3.44.2 (D:\flutter)
- Android SDK 36.0.0 (D:\android-sdk)  
- Java 17 (OpenJDK - Microsoft)
- Gradle 8.11.1 (ter-cache di %USERPROFILE%\.gradle\wrapper\dists\)
- AGP 8.11.1 (Android Gradle Plugin)
- Kotlin 2.2.20
- Flutter pub cache (semua paket sudah di-cache)

## APK Terakhir Berhasil Build
- File: `build\app\outputs\flutter-apk\gentix-apps-update.apk`
- Size: **71.56 MB**
- Build time: ~12 menit (first build dengan R8 minify)
- Build time berikutnya: ~3-5 menit (incremental)

## Cara Build APK Tanpa Internet

### Opsi 1: Menggunakan Script PowerShell (DIREKOMENDASIKAN)
```powershell
cd d:\laragon\www\gentix-apps-mobile
.\build_offline.ps1
```

Dengan clean terlebih dahulu:
```powershell
.\build_offline.ps1 -Clean
```

Dengan output verbose:
```powershell
.\build_offline.ps1 -Verbose
```

### Opsi 2: Command Manual
```powershell
cd d:\laragon\www\gentix-apps-mobile
flutter build apk --release --no-pub
```

Hasil APK ada di:
```
build\app\outputs\flutter-apk\app-release.apk
```

Rename manual:
```powershell
Rename-Item build\app\outputs\flutter-apk\app-release.apk gentix-apps-update.apk
```

## Lokasi Output APK
```
d:\laragon\www\gentix-apps-mobile\build\app\outputs\flutter-apk\gentix-apps-update.apk
```

## Verifikasi Cache Offline

### Cek Gradle cache:
```powershell
ls "$env:USERPROFILE\.gradle\wrapper\dists\gradle-8.11.1-all"
```

### Cek Flutter pub cache:
```powershell
flutter pub deps
```

### Cek Android SDK:
```powershell
ls D:\android-sdk\platforms
ls D:\android-sdk\build-tools
```

## Troubleshooting

### Error: "Could not resolve..."
- Artinya dependency belum ter-cache
- Perlu internet untuk cache pertama kali
- Jalankan `flutter build apk --release` dengan internet sekali

### Error: "Gradle not found"
- Pastikan ada file .zip.ok di:  
  `%USERPROFILE%\.gradle\wrapper\dists\gradle-8.11.1-all\*\`

### Error: "SDK not found"
- Pastikan D:\android-sdk ada dan berisi platform android-36

### Warning KGP (Kotlin Gradle Plugin)
- Ini hanya WARNING, tidak mempengaruhi build
- Plugins yang affected: audioplayers_android, camera_android_camerax, 
  device_info_plus, image_picker_android, mobile_scanner, shared_preferences_android

## Info Versi Dependencies (pubspec.yaml)
| Package | Version |
|---------|---------|
| dio | ^5.4.0 |
| mobile_scanner | ^7.2.0 |
| flutter_secure_storage | ^10.0.0 |
| provider | ^6.1.1 |
| sqflite | ^2.3.0 |
| camera | ^0.11.0+1 |
| audioplayers | ^5.2.1 |
| google_fonts | ^8.1.0 |
| lottie | ^3.0.0 |

## Struktur Project
```
gentix-apps-mobile/
├── lib/                    # Dart source code
│   └── screens/
│       └── gate/
│           └── gate_scan_screen.dart
├── android/
│   ├── app/build.gradle.kts  (minSdk=24, targetSdk=flutter.targetSdkVersion)
│   ├── gradle.properties
│   ├── local.properties      (sdk.dir=D:\android-sdk, flutter.sdk=D:\flutter)
│   └── gradle/wrapper/
│       └── gradle-wrapper.properties  (gradle-8.11.1-all)
├── assets/
│   ├── images/
│   └── sounds/
├── build_offline.ps1       # Script build offline ini
└── pubspec.yaml
```
