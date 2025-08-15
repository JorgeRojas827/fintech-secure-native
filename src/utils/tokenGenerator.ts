import CryptoJS from "crypto-js";

let SECRET_KEY = "SECURE_CARD_VIEW_SECRET_KEY_2024";

export interface SecureToken {
  token: string;
  signature: string;
  expiresAt: number;
}

export function setSecretKey(secretKey: string): void {
  SECRET_KEY = secretKey;
}

export function generateSecureToken(cardId: string): SecureToken {
  const timestamp = Date.now();
  const expiresAt = timestamp + 60 * 60 * 1000;
  const token = `${cardId}:${timestamp}`;
  const dataToSign = `${cardId}:${token}`;
  const signature = CryptoJS.HmacSHA256(dataToSign, SECRET_KEY).toString();

  return {
    token,
    signature,
    expiresAt,
  };
}

export function validateToken(
  cardId: string,
  token: string,
  signature: string
): boolean {
  try {
    const dataToSign = `${cardId}:${token}`;
    const expectedSignature = CryptoJS.HmacSHA256(
      dataToSign,
      SECRET_KEY
    ).toString();

    if (expectedSignature !== signature) {
      return false;
    }

    const timestamp = parseInt(token.split(":")[1], 10);
    const currentTime = Date.now();
    const tokenAge = currentTime - timestamp;

    return tokenAge <= 60 * 60 * 1000;
  } catch (error) {
    return false;
  }
}

export function generateMockToken(cardId: string): SecureToken {
  return generateSecureToken(cardId);
}
