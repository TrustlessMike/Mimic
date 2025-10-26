# Wickett App Architecture

## Overview
Wickett is an iOS app that implements authentication using Privy (with Apple and Google OAuth) and bridges it to Firebase for backend services.

## Project Structure

```
Sources/Wickett/
├── App/
│   └── WickettApp.swift              # Main app entry point
│
├── Core/                              # Core functionality
│   ├── Authentication/
│   │   ├── AuthCoordinator.swift    # Main auth coordinator
│   │   ├── Services/
│   │   │   ├── HybridPrivyService.swift        # Privy<->Firebase bridge
│   │   │   └── AuthenticationService.swift     # Auth protocol
│   │   └── Models/
│   │       └── User.swift (in Shared/Models)
│   │
│   ├── Firebase/
│   │   ├── FirebaseCallableClient.swift  # Firebase functions client
│   │   └── FirebaseManager.swift         # Firebase manager
│   │
│   └── Configuration/
│       └── AppConfiguration.swift         # Centralized config
│
├── Features/                          # Feature modules
│   ├── Auth/
│   │   └── Views/
│   │       └── LoginView.swift       # Login screen
│   │
│   └── Home/
│       └── Views/
│           └── HomeView.swift        # Home/authenticated screen
│
├── Shared/                            # Shared resources
│   ├── Models/
│   │   ├── User.swift                # User model
│   │   └── AuthError.swift           # Auth errors
│   │
│   ├── Components/
│   │   └── LoadingView.swift         # Reusable loading view
│   │
│   └── Extensions/                    # Swift extensions (future)
│
├── ContentView.swift                  # Root view coordinator
│
└── Resources/                         # App resources (in root)
    ├── Info.plist
    ├── GoogleService-Info.plist
    └── Wickett.entitlements
```

## Architecture Patterns

### 1. **MVVM-C (Model-View-ViewModel-Coordinator)**
- **Models**: User, AuthError
- **Views**: LoginView, HomeView, ContentView
- **Coordinators**: AuthCoordinator
- **Services**: HybridPrivyService, FirebaseCallableClient

### 2. **Dependency Injection**
- Services are injected via `@StateObject` and `@EnvironmentObject`
- Singleton pattern for coordinators (`AuthCoordinator.shared`)

### 3. **Protocol-Oriented**
- `AuthenticationService` protocol defines authentication capabilities
- Allows for easy mocking and testing

### 4. **Separation of Concerns**
- **Core**: Business logic and services
- **Features**: UI grouped by feature
- **Shared**: Reusable components and models

## Authentication Flow

```
┌─────────────────┐
│   User taps     │
│  Sign In button │
└────────┬────────┘
         │
         v
┌─────────────────────────┐
│   AuthCoordinator       │
│  signInWithPrivyOAuth() │
└────────┬────────────────┘
         │
         v
┌──────────────────────────────┐
│  HybridPrivyService          │
│  authenticateWithProvider()  │
└────────┬─────────────────────┘
         │
         v
┌──────────────────────┐
│   Privy SDK          │
│  oAuth.login()       │
└────────┬─────────────┘
         │
         v
┌──────────────────────────────┐
│  Firebase Cloud Function     │
│  createFirebaseCustomToken   │
└────────┬─────────────────────┘
         │
         v
┌──────────────────────┐
│  Firebase Auth       │
│  signIn(customToken) │
└────────┬─────────────┘
         │
         v
┌──────────────────────┐
│  Firestore           │
│  Save user data      │
└────────┬─────────────┘
         │
         v
┌──────────────────────┐
│  UI Updates          │
│  Show HomeView       │
└──────────────────────┘
```

## Configuration

All configuration values are centralized in `AppConfiguration.swift`:

- **Privy**: App ID, Client ID, URL Scheme
- **Firebase**: Project ID, Function names, Region
- **App**: Bundle ID, App Name

## Adding New Features

### 1. Create a new feature module:
```
Features/
└── YourFeature/
    ├── Views/
    │   └── YourFeatureView.swift
    ├── ViewModels/
    │   └── YourFeatureViewModel.swift
    └── Models/ (if feature-specific)
        └── YourFeatureModel.swift
```

### 2. Create shared components in `Shared/Components/`
```swift
// Example: Shared/Components/CustomButton.swift
struct CustomButton: View {
    let title: String
    let action: () -> Void
    // ...
}
```

### 3. Add navigation in ContentView or create a coordinator

## Key Files

| File | Purpose |
|------|---------|
| `WickettApp.swift` | App entry point, Firebase initialization |
| `ContentView.swift` | Root view, routes to Login/Home |
| `AuthCoordinator.swift` | Manages auth state, coordinates auth flow |
| `HybridPrivyService.swift` | Bridges Privy ↔ Firebase |
| `AppConfiguration.swift` | Centralized configuration |
| `LoginView.swift` | Login UI with Apple/Google buttons |
| `HomeView.swift` | Authenticated user home screen |

## Dependencies

- **PrivySDK**: OAuth authentication with embedded wallets
- **FirebaseAuth**: Custom token authentication
- **FirebaseFirestore**: User data storage
- **FirebaseFunctions**: Cloud Functions for token creation

## Best Practices

1. **Keep views simple**: Views should only handle UI
2. **Business logic in services**: Put logic in coordinators/services
3. **Use protocols**: Define interfaces for testability
4. **Centralize configuration**: All config in `AppConfiguration`
5. **Feature-based organization**: Group files by feature, not type
6. **Reusable components**: Extract common UI into `Shared/Components/`

## Testing Structure (Future)

```
Tests/
├── UnitTests/
│   ├── Core/
│   │   └── AuthenticationTests.swift
│   └── Services/
│       └── HybridPrivyServiceTests.swift
└── UITests/
    └── AuthFlowTests.swift
```

## Firebase Cloud Functions

Located in `/functions/` directory:
- `privy-firebase-bridge.ts`: Creates Firebase custom tokens from Privy users
- Deployed to: `us-central1`
- Function name: `createFirebaseCustomToken`

## Environment Setup

1. Install dependencies: Privy SDK, Firebase SDK
2. Configure `GoogleService-Info.plist` with Firebase project
3. Set up entitlements for Apple Sign In
4. Configure Privy dashboard with OAuth credentials
5. Deploy Firebase Cloud Functions

---

**Last Updated**: 2025-10-26
