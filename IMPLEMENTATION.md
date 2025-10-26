# Wickett - Privy ↔ Firebase Bridge Implementation

## Architecture Overview

Wickett implements a **Privy-first authentication with Firebase bridging** pattern. This allows you to use Privy's embedded wallet functionality (FREE tier) while maintaining a Firebase backend for user data and custom claims.

### Authentication Flow

```
User taps "Sign in with Apple"
    ↓
[iOS] Privy SDK authenticates with Apple
    ↓
[iOS] Privy creates embedded wallet
    ↓
[iOS] Call Firebase Cloud Function: createFirebaseCustomToken
    ↓
[Firebase] Validate Privy user → Create custom token
    ↓
[Firebase] Save user data to Firestore
    ↓
[iOS] Sign into Firebase with custom token
    ↓
✅ User authenticated in both Privy AND Firebase
```

## Key Components

### iOS (Swift)

#### 1. **HybridPrivyService.swift**
Main service that orchestrates the Privy → Firebase bridge.

**Key Methods:**
- `authenticateWithApple()` - Handles Apple Sign-In through Privy
- `bridgeToFirebase()` - Creates Firebase custom token and signs in
- `signOut()` - Signs out from both Privy and Firebase

**Flow:**
```swift
// 1. Authenticate with Privy
try await privyClient?.loginWithApple(idToken: identityToken, nonce: nonce)

// 2. Call Firebase Function to get custom token
let result = try await firebaseCallable.call("createFirebaseCustomToken", data: ...)

// 3. Sign into Firebase with custom token
let authResult = try await Auth.auth().signIn(withCustomToken: customToken)
```

#### 2. **FirebaseCallableClient.swift**
Wrapper around Firebase Cloud Functions with retry logic and automatic ID token injection.

**Features:**
- Automatic retry with exponential backoff
- ID token injection for authenticated calls
- Timeout handling

#### 3. **AuthCoordinator.swift**
Coordinates authentication state across the app using HybridPrivyService.

**Published Properties:**
- `isAuthenticated` - Overall auth state
- `isLoading` - Loading state during auth
- `currentUser` - User data with wallet address

### Firebase (Backend)

#### Cloud Function: `createFirebaseCustomToken`

**Location:** `functions/src/privy-firebase-bridge.ts`

**Input:**
```typescript
{
  privyUserId: string,
  privyUserData: {
    email?: string,
    displayName?: string,
    wallet?: { address: string }
  },
  authMethod: "privy_apple" | "privy_email" | "privy",
  timestamp: number
}
```

**Output:**
```typescript
{
  customToken: string,  // Firebase custom token
  firebaseUid: string,  // "privy_{privyUserId}"
  success: boolean
}
```

**What it does:**
1. Validates Privy user ID
2. Creates Firebase UID: `privy_{privyUserId}`
3. Generates custom token with claims:
   - `privyUserId`
   - `authProvider: "privy"`
   - `authMethod` (apple/email/google)
   - `walletAddress`
   - `email`
4. Saves/updates user in Firestore `/users/{firebaseUid}`

## Firebase Structure

### Firestore Collections

#### `/users/{firebaseUid}`
```json
{
  "privyUserId": "did:privy:abc123",
  "email": "user@example.com",
  "displayName": "John Doe",
  "walletAddress": "0x1234...5678",
  "authProvider": "privy",
  "authMethod": "privy_apple",
  "lastSignIn": Timestamp,
  "updatedAt": Timestamp
}
```

### Firebase Auth Custom Claims

Each Firebase user has custom claims:
```json
{
  "privyUserId": "did:privy:abc123",
  "authProvider": "privy",
  "authMethod": "privy_apple",
  "walletAddress": "0x1234...5678",
  "email": "user@example.com",
  "timestamp": 1234567890
}
```

## Setup Instructions

### Prerequisites

1. **Firebase Project**
   - Project ID: `wickett-13423`
   - Enable Authentication
   - Enable Firestore
   - Enable Cloud Functions

2. **Privy Account**
   - App ID: `cmh5i82000072jl0cixsq20k7`
   - FREE tier is sufficient
   - Enable Apple Sign-In in Privy Dashboard

### Step 1: Firebase Setup

1. **Download GoogleService-Info.plist**
   ```bash
   # Go to Firebase Console > Project Settings > iOS App
   # Download GoogleService-Info.plist
   # Replace: Resources/GoogleService-Info.plist
   ```

2. **Deploy Cloud Functions**
   ```bash
   cd functions
   npm install
   npm run deploy
   ```

3. **Firestore Security Rules**
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /users/{userId} {
         // Users can only read/write their own data
         allow read, write: if request.auth != null && request.auth.uid == userId;
       }
     }
   }
   ```

### Step 2: Privy Dashboard Setup

1. Go to https://dashboard.privy.io
2. Navigate to your app settings
3. **Enable Apple Sign-In**
   - Add your Apple Developer Team ID
   - Configure bundle identifier: `com.syndicatemike.Wickett`
4. **Configure Allowed Origins**
   - Add: `http://localhost` (for iOS native)

### Step 3: iOS Build

```bash
cd /Users/syndicatemike/Wickett
swift build
```

## File Structure

```
Wickett/
├── Sources/Wickett/
│   ├── HybridPrivyService.swift       # Main Privy ↔ Firebase bridge
│   ├── FirebaseCallableClient.swift   # Firebase Functions wrapper
│   ├── AuthCoordinator.swift          # Auth state coordinator
│   ├── ContentView.swift              # UI
│   ├── WickettApp.swift               # App entry point
│   ├── FirebaseManager.swift          # (Legacy - mostly unused now)
│   └── PrivyManager.swift             # (Legacy - mostly unused now)
│
├── functions/
│   ├── src/
│   │   ├── privy-firebase-bridge.ts  # Custom token Cloud Function
│   │   └── index.ts                   # Functions entry point
│   ├── package.json
│   └── tsconfig.json
│
├── Resources/
│   └── GoogleService-Info.plist       # Firebase config
│
└── Package.swift                       # Swift package dependencies

```

## Benefits of This Approach

✅ **FREE Tier Compatible** - Works on Privy's free plan
✅ **Wallet Creation** - Embedded wallets via Privy
✅ **Firebase Backend** - Full Firebase ecosystem access
✅ **Custom Claims** - Firebase Auth with Privy user data
✅ **Single Source of Truth** - Privy user ID links both systems
✅ **Firestore Security** - Row-level security via Firebase Auth

## User Data Flow

1. **Sign In**
   - Privy authenticates user
   - Privy creates wallet
   - Firebase creates custom token
   - Firebase Auth session established
   - User data saved to Firestore

2. **App Usage**
   - Read user data from Firestore
   - Query with Firebase UID
   - Sign transactions with Privy wallet
   - All secured by Firebase Auth rules

3. **Sign Out**
   - Privy session cleared
   - Firebase Auth session cleared
   - Local user data cleared

## Testing Checklist

- [ ] Apple Sign-In works through Privy
- [ ] Wallet address is created
- [ ] Firebase custom token is generated
- [ ] Firebase Auth session is created
- [ ] User document exists in Firestore
- [ ] User can see wallet address in UI
- [ ] Sign out clears both sessions
- [ ] Re-login preserves user data

## Troubleshooting

### "Failed to create Firebase token"
- Check that Cloud Functions are deployed
- Verify Firebase project ID matches
- Check function logs: `firebase functions:log`

### "Privy authentication failed"
- Verify Privy App ID is correct
- Check Apple Sign-In is enabled in Privy Dashboard
- Verify bundle identifier matches

### "Permission denied" in Firestore
- Check Firestore security rules
- Verify user is authenticated with Firebase
- Check Firebase UID matches Firestore document ID

## Next Steps

1. Deploy Firebase Cloud Functions
2. Test authentication flow end-to-end
3. Add additional Privy auth methods (Email, Google)
4. Implement transaction signing with Privy wallet
5. Add Firestore queries for user data

---

**Status:** Implementation complete, ready for deployment and testing.
