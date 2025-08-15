# @vaultfintech/secure-native

React Native native module for securely displaying sensitive card data.

## 🔒 Security Features

### Implemented Security Requirements

- ✅ **Token Validation**: HMAC-SHA256 signature verification
- ✅ **Token TTL**: Tokens with limited lifetime (1 hour)
- ✅ **Screenshot Blocking**: FLAG_SECURE on Android / protection on iOS
- ✅ **Auto-hide**: Automatic blur when app goes to background
- ✅ **Session Timeout**: Automatic close after configurable time
- ✅ **No sensitive logs**: Verification that sensitive data is not saved in logs

### Events Exposed to JavaScript

```typescript
// Available events
onSecureViewOpened(cardId: string) => void
onValidationError(code: string, message: string) => void
onCardDataShown(cardId: string, timestamp: number) => void
onSecureViewClosed(cardId: string, reason: CloseReason, duration: number) => void
```

## 📦 Installation

```bash
npm install @vaultfintech/secure-native
# or
yarn add @vaultfintech/secure-native
```

### iOS Configuration

Add to `Podfile`:

```ruby
pod 'RNSecureCardNative', :path => '../node_modules/@vaultfintech/secure-native'
```

### Android Configuration

Add to `android/settings.gradle`:

```gradle
include ':react-native-secure-card-native'
project(':react-native-secure-card-native').projectDir = new File(rootProject.projectDir, '../node_modules/@vaultfintech/secure-native/android')
```

## 🔐 Security Configuration

### Setting Secret Key

For production use, you should set a custom secret key:

```typescript
import { setSecretKey } from "@vaultfintech/secure-native";

// Set your custom secret key (do this early in your app initialization)
setSecretKey("your-custom-secret-key-here");
```

**Important**: Change the default secret key in production environments.

## 🚀 Basic Usage

### 1. React Native Hook

```typescript
import {
  useSecureCard,
  generateSecureToken,
} from "@vaultfintech/secure-native";

function MyComponent() {
  const { openSecureView, closeSecureView, isOpen, error } = useSecureCard();

  const showCardData = async () => {
    const { token, signature } = generateSecureToken("card-123");

    await openSecureView({
      cardId: "card-123",
      token,
      signature,
      cardData: {
        pan: "4111111111111111",
        cvv: "123",
        expiry: "12/25",
        holder: "JOHN DOE",
      },
      config: {
        timeout: 60000,
        blockScreenshots: true,
        theme: "dark",
      },
    });
  };

  return <Button onPress={showCardData} title="View Sensitive Data" />;
}
```

### 2. Direct Module Usage

```typescript
import SecureCardNative, {
  generateSecureToken,
  type OpenSecureViewParams,
} from "@vaultfintech/secure-native";

// Generate secure token
const { token, signature } = generateSecureToken("card-123");

// Configure parameters
const params: OpenSecureViewParams = {
  cardId: "card-123",
  token,
  signature,
  cardData: {
    pan: "4111111111111111",
    cvv: "123",
    expiry: "12/25",
    holder: "JOHN DOE",
  },
  config: {
    timeout: 60000,
    blockScreenshots: true,
    requireBiometric: false,
    blurOnBackground: true,
    theme: "dark",
  },
};

// Open secure view
await SecureCardNative.openSecureView(params);
```

## 📋 API Reference

### Types

```typescript
interface SecureCardData {
  pan: string;
  cvv: string;
  expiry: string;
  holder: string;
}

interface SecureViewConfig {
  timeout?: number; // Time in ms (default: 60000)
  blockScreenshots?: boolean; // Block screenshots (default: true)
  requireBiometric?: boolean; // Require biometric (default: false)
  blurOnBackground?: boolean; // Blur on background (default: true)
  theme?: "light" | "dark"; // Visual theme (default: "dark")
}

interface OpenSecureViewParams {
  cardId: string;
  token: string;
  signature: string;
  cardData: SecureCardData;
  config?: SecureViewConfig;
}

type ValidationErrorCode =
  | "TOKEN_EXPIRED"
  | "TOKEN_INVALID"
  | "BIOMETRIC_FAILED"
  | "PERMISSION_DENIED";

type CloseReason = "USER_DISMISS" | "TIMEOUT" | "ERROR" | "BACKGROUND";
```

### Methods

```typescript
// Open secure view
openSecureView(params: OpenSecureViewParams): Promise<void>

// Close secure view
closeSecureView(): void

// Get module constants
getConstants(): { [key: string]: any }

// Check availability
isAvailable(): boolean

// Event Listeners
onSecureViewOpened(callback: (data: { cardId: string }) => void): () => void
onValidationError(callback: (error: ValidationError) => void): () => void
onCardDataShown(callback: (data: { cardId: string; timestamp: number }) => void): () => void
onSecureViewClosed(callback: (data: CloseEventData) => void): () => void

// Remove all listeners
removeAllListeners(): void
```

### Utilities

```typescript
// Generate secure token
generateSecureToken(cardId: string): { token: string; signature: string; expiresAt: number }

// Validate token (client-side)
validateToken(cardId: string, token: string, signature: string): boolean

// Mock token for development
generateMockToken(cardId: string): SecureToken

// Set custom secret key
setSecretKey(secretKey: string): void
```

## 🔧 Advanced Configuration

### Environment Variables

Configure the secret key for HMAC:

```typescript
// In your app initialization
import { setSecretKey } from "@vaultfintech/secure-native";

// Use environment variable or custom key
const secretKey = process.env.SECURE_CARD_SECRET_KEY || "your-custom-key";
setSecretKey(secretKey);
```

### UI Customization

```typescript
const config: SecureViewConfig = {
  theme: "dark", // 'light' | 'dark'
  timeout: 30000, // 30 seconds
  blockScreenshots: true, // Block screenshots
  blurOnBackground: true, // Blur on background
  requireBiometric: true, // Require fingerprint/Face ID
};
```

## 🏗 Implementation Flow

### Expected Flow (Summary)

1. **User opens Dashboard (RN)**: Sees accounts and cards
2. **Tap "View sensitive data"**: RN generates/renews secureToken
3. **RN calls openSecureView(cardId, token)**:
4. **Native validates token (TTL/rules)**:
   - If ok → blocks screenshots, shows data and emits shown
   - If fail → emits validation_error and closes or allows retry
5. **User closes view or timeout expires** → emits closed
6. **Entire flow from React Native should have unit tests**

### Backend Integration

```typescript
// In your API, generate secure tokens
import { generateSecureToken } from "@vaultfintech/secure-native";

app.post("/api/cards/:cardId/secure-token", async (req, res) => {
  const { cardId } = req.params;

  // Validate user permissions
  if (!(await userHasCardAccess(req.user.id, cardId))) {
    return res.status(403).json({ error: "Access denied" });
  }

  // Generate token
  const secureToken = generateSecureToken(cardId);

  res.json({
    token: secureToken.token,
    signature: secureToken.signature,
    expiresAt: secureToken.expiresAt,
  });
});
```

## 🔐 Security Considerations

### Implemented

- ✅ HMAC-SHA256 signature validation
- ✅ Tokens with TTL (Time To Live)
- ✅ Native screenshot blocking
- ✅ Auto-hide in background
- ✅ Configurable timeouts
- ✅ Auditable events

### Recommendations

- 🔑 Change `SECRET_KEY` in production
- 🕐 Use short TTL for tokens (15-60 minutes)
- 📱 Implement biometric authentication when available
- 🔄 Renew tokens on each use
- 📊 Monitor security events

## 📄 License

MIT © [Jorge Luis Rojas Poma](https://github.com/jorgeluisrojaspoma)

## 🤝 Contributing

1. Fork the project
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📞 Support

- Email: jorgerojaspoma09@gmail.com
- GitHub Issues: [Report an issue](https://github.com/io-fintech/secure-card-native/issues)

---

⚠️ **Important**: This module handles sensitive data. Make sure to follow security best practices and comply with applicable regulations (PCI DSS, GDPR, etc.).
