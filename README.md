# Wickett

A SwiftUI boilerplate iOS app that integrates Privy SDK for Apple Sign In authentication.

## Features

- SwiftUI-based modern iOS app
- Apple Sign In integration via Privy SDK
- Clean architecture with separated concerns
- User authentication state management
- Error handling and user feedback

## Project Structure

```
Wickett/
├── Package.swift                # Swift Package Manager configuration
├── Sources/
│   └── Wickett/
│       ├── WickettApp.swift    # Main app entry point
│       ├── ContentView.swift   # Main UI with Apple Sign In button
│       └── PrivyManager.swift  # Privy SDK integration manager
└── Resources/
    └── Info.plist              # App configuration
```

## Setup Instructions

### 1. Prerequisites

- Xcode 14.0 or later
- iOS 15.0+ deployment target
- Apple Developer account
- Privy account and App ID

### 2. Configuration

1. **Update Privy App ID**: 
   - Open `PrivyManager.swift`
   - Replace `"YOUR_PRIVY_APP_ID"` with your actual Privy App ID

2. **Configure URL Scheme**:
   - Open `Resources/Info.plist`
   - Update the URL scheme from `privy-YOUR_PRIVY_APP_ID` to `privy-[your-actual-app-id]`

3. **Apple Sign In Setup**:
   - In Xcode, select your project target
   - Go to "Signing & Capabilities"
   - Add "Sign in with Apple" capability
   - Ensure your Bundle ID is properly configured

### 3. Build and Run

#### Using Xcode:

1. Open Xcode
2. Select "File" > "Open"
3. Navigate to the `Wickett` folder and select it
4. Choose your target device/simulator
5. Press Cmd+R to build and run

#### Using Swift Package Manager:

```bash
cd Wickett
swift build
swift run
```

## Key Components

### PrivyManager

Singleton class that manages:
- Privy SDK initialization
- Apple Sign In authentication
- User session management
- Authentication state tracking

### ContentView

Main UI that provides:
- Apple Sign In button
- User authentication status
- User information display
- Sign out functionality

### App Configuration

The `Info.plist` includes:
- URL schemes for deep linking
- Apple Sign In configuration
- App transport security settings

## Important Notes

1. **Replace Placeholder Values**: 
   - You must replace `"YOUR_PRIVY_APP_ID"` with your actual Privy App ID
   - Update the URL scheme in Info.plist accordingly

2. **Apple Developer Configuration**:
   - Ensure your app is properly configured in Apple Developer portal
   - Enable Sign in with Apple capability
   - Configure associated domains if needed

3. **Testing**:
   - Apple Sign In requires a real device or proper simulator setup
   - Ensure you're signed into iCloud on your test device

4. **Security**:
   - Never commit your actual Privy App ID to public repositories
   - Use environment variables or configuration files for sensitive data

## Dependencies

- PrivySDK: Authentication and wallet management
- AuthenticationServices: Apple's Sign in with Apple framework
- SwiftUI: Modern declarative UI framework

## License

This is a boilerplate template. Apply your own license as needed.