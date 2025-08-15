# fintech-secure-native

React Native native module for securely displaying sensitive card data with enterprise-grade security features.

## 🔒 Security Features

### Implemented Security Requirements

- ✅ **Token Validation**: HMAC-SHA256 signature verification
- ✅ **Token TTL**: Tokens with limited lifetime (1 hour)
- ✅ **Screenshot Blocking**: FLAG_SECURE on Android / protection on iOS
- ✅ **Auto-hide**: Automatic blur when app goes to background
- ✅ **Session Timeout**: Automatic close after configurable time
- ✅ **No sensitive logs**: Verification that sensitive data is not saved in logs
- ✅ **Background Protection**: Automatic blur overlay when app loses focus
- ✅ **Screen Recording Detection**: iOS screen recording detection and auto-close

### Events Exposed to JavaScript

```typescript
// Available events
onSecureViewOpened(cardId: string) => void
onValidationError(code: string, message: string, recoverable: boolean) => void
onCardDataShown(cardId: string, timestamp: number) => void
onSecureViewClosed(cardId: string, reason: CloseReason, duration: number) => void
```

## 📦 Installation

```bash
npm install fintech-secure-native
# or
yarn add fintech-secure-native
```

### iOS Configuration

Add to `ios/Podfile`:

```ruby
pod 'SecureCardNative', :path => '../node_modules/fintech-secure-native'
```

Then run:

```bash
cd ios && pod install
```

### Android Configuration

The module is automatically linked. No additional configuration required.

## 🚀 Basic Usage

### 1. React Native Hook (Recommended)

```typescript
import {
  useSecureCard,
  generateSecureToken,
} from "fintech-secure-native";

function MyComponent() {
  const { openSecureView, closeSecureView, isOpen, error, isOpening } = useSecureCard();

  const showCardData = async () => {
    try {
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
    } catch (error) {
      console.error("Failed to open secure view:", error);
    }
  };

  return (
    <View>
      <Button
        onPress={showCardData}
        title="View Sensitive Data"
        disabled={isOpening}
      />
      {error && <Text>Error: {error.message}</Text>}
    </View>
  );
}
```

### 2. Direct Module Usage

```typescript
import SecureCardNative, {
  generateSecureToken,
  type OpenSecureViewParams,
} from "fintech-secure-native";

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
try {
  await SecureCardNative.openSecureView(params);
} catch (error) {
  console.error("Failed to open secure view:", error);
}
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

interface ValidationError {
  code: ValidationErrorCode;
  message: string;
  recoverable: boolean;
}

type ValidationErrorCode =
  | "TOKEN_EXPIRED"
  | "TOKEN_INVALID"
  | "BIOMETRIC_FAILED"
  | "PERMISSION_DENIED";

type CloseReason =
  | "USER_DISMISS"
  | "TIMEOUT"
  | "SCREENSHOT_ATTEMPT"
  | "SCREEN_RECORDING_DETECTED"
  | "BACKGROUND";

interface CloseEventData {
  cardId: string;
  reason: CloseReason;
  duration: number;
}
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
import { setSecretKey } from "fintech-secure-native";

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
import { generateSecureToken } from "fintech-secure-native";

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
- ✅ Native screenshot blocking (FLAG_SECURE on Android)
- ✅ Auto-hide in background with blur overlay
- ✅ Configurable timeouts
- ✅ Auditable events
- ✅ Screen recording detection (iOS)
- ✅ Screenshot attempt detection (iOS)

### Recommendations

- 🔑 Change `SECRET_KEY` in production
- 🕐 Use short TTL for tokens (15-60 minutes)
- 📱 Implement biometric authentication when available
- 🔄 Renew tokens on each use
- 📊 Monitor security events
- 🔒 Use HTTPS for all API communications
- 🛡️ Implement rate limiting on token generation

## 🧪 Testing

### Unit Tests

```typescript
import { generateSecureToken, validateToken } from "fintech-secure-native";

describe("Token Generation", () => {
  it("should generate valid tokens", () => {
    const { token, signature } = generateSecureToken("test-card");
    expect(validateToken("test-card", token, signature)).toBe(true);
  });

  it("should reject expired tokens", () => {
    const { token, signature } = generateSecureToken("test-card");
    // Simulate time passing
    jest.advanceTimersByTime(3600001); // 1 hour + 1ms
    expect(validateToken("test-card", token, signature)).toBe(false);
  });
});
```

## 📄 License

MIT © [Jorge Luis Rojas Poma](https://github.com/JorgeRojas827)

## 🤝 Contributing

1. Fork the project
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📞 Support

- Email: jorgerojaspoma09@gmail.com
- GitHub Issues: [Report an issue](https://github.com/JorgeRojas827/fintech-secure-native/issues)

## 📦 Build

```bash
# Install dependencies
npm install

# Build the library
npm run build

# Run tests
npm test

# Type checking
npm run type-check

# Linting
npm run lint
```

---

⚠️ **Important**: This module handles sensitive data. Make sure to follow security best practices and comply with applicable regulations (PCI DSS, GDPR, etc.).
