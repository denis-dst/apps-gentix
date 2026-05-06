# GenTix Officer App

A Flutter application for event officers to manage ticket sales, voucher redemption, and gate access control.

## Features

- **Authentication**: Secure login with Laravel Sanctum.
- **Event Selection**: Choose from a list of active events for your tenant.
- **Security Code**: Access restricted events using a secondary security code.
- **Ticketing (POS)**:
  - **Redemption**: Scan E-Voucher QR and link it to a physical wristband.
  - **Sales**: Direct ticket sales with customer detail recording.
- **Gate Control**:
  - **High-Speed Scanning**: Continuous scanning for entry (IN) and exit (OUT).
  - **Visual Feedback**: Large green/red indicators for quick processing.
  - **Anti-Passback**: Real-time validation to prevent reuse.

## Technology Stack

- **Framework**: Flutter (Dart)
- **State Management**: Provider
- **Networking**: Dio
- **Storage**: Flutter Secure Storage (Tokens)
- **Scanning**: Mobile Scanner
- **Animations**: Animate Do, Lottie

## Getting Started

1. Ensure you have Flutter installed on your machine.
2. Open the project in Android Studio or VS Code.
3. Run `flutter pub get` to install dependencies.
4. Update `lib/core/constants.dart` with your local backend URL.
5. Build the APK using `flutter build apk`.

## API Integration

The app connects to the GenTix Laravel Backend. Ensure the following endpoints are available:
- `POST /api/login`
- `GET /api/events`
- `GET /api/events/{event}/analytics`
- `POST /api/pos/redeem`
- `POST /api/pos/events/{event}/sell`
- `POST /api/gate/scan`
