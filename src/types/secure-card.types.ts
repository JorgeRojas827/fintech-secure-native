export interface SecureCardData {
  pan: string;
  cvv: string;
  expiry: string;
  holder: string;
}

export interface SecureViewConfig {
  timeout?: number;
  blockScreenshots?: boolean;
  requireBiometric?: boolean;
  blurOnBackground?: boolean;
  theme?: "light" | "dark";
}

export interface OpenSecureViewParams {
  cardId: string;
  token: string;
  signature: string;
  cardData: SecureCardData;
  config?: SecureViewConfig;
}

export type ValidationErrorCode =
  | "TOKEN_EXPIRED"
  | "TOKEN_INVALID"
  | "BIOMETRIC_FAILED"
  | "PERMISSION_DENIED";

export interface ValidationError {
  code: ValidationErrorCode;
  message: string;
  recoverable: boolean;
}

export type CloseReason = "USER_DISMISS" | "TIMEOUT" | "ERROR" | "BACKGROUND";

export interface CloseEventData {
  cardId: string;
  reason: CloseReason;
  duration: number;
}
