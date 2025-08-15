import { NativeModules, NativeEventEmitter, Platform } from "react-native";
import type { TurboModule } from "react-native";
import { OpenSecureViewParams, ValidationError, CloseEventData } from "./types";

export interface Spec extends TurboModule {
  openSecureView(params: string): Promise<void>;
  closeSecureView(): void;
  getConstants(): { [key: string]: any };
}

const SecureCardNativeModule = Platform.select({
  ios: NativeModules.SecureCardViewModule,
  android: NativeModules.SecureCardViewModule,
  default: null,
});

if (!SecureCardNativeModule) {
  throw new Error(
    "SecureCardNative module not found. Please ensure the native module is properly linked."
  );
}

const eventEmitter = new NativeEventEmitter(SecureCardNativeModule);

class SecureCardNative {
  private listeners: Map<string, any> = new Map();

  async openSecureView(params: OpenSecureViewParams): Promise<void> {
    try {
      const serializedParams = JSON.stringify({
        ...params,
        config: {
          timeout: params.config?.timeout ?? 60000,
          blockScreenshots: params.config?.blockScreenshots ?? true,
          requireBiometric: params.config?.requireBiometric ?? false,
          blurOnBackground: params.config?.blurOnBackground ?? true,
          theme: params.config?.theme ?? "dark",
        },
      });

      await SecureCardNativeModule.openSecureView(serializedParams);
    } catch (error) {
      console.error("Error opening secure view:", error);
      throw error;
    }
  }

  closeSecureView(): void {
    SecureCardNativeModule.closeSecureView();
  }

  onSecureViewOpened(callback: (data: { cardId: string }) => void): () => void {
    const listener = eventEmitter.addListener("onSecureViewOpened", callback);
    this.listeners.set("onSecureViewOpened", listener);
    return () => listener.remove();
  }

  onValidationError(callback: (error: ValidationError) => void): () => void {
    const listener = eventEmitter.addListener("onValidationError", callback);
    this.listeners.set("onValidationError", listener);
    return () => listener.remove();
  }

  onCardDataShown(
    callback: (data: { cardId: string; timestamp: number }) => void
  ): () => void {
    const listener = eventEmitter.addListener("onCardDataShown", callback);
    this.listeners.set("onCardDataShown", listener);
    return () => listener.remove();
  }

  onSecureViewClosed(callback: (data: CloseEventData) => void): () => void {
    const listener = eventEmitter.addListener("onSecureViewClosed", callback);
    this.listeners.set("onSecureViewClosed", listener);
    return () => listener.remove();
  }

  removeAllListeners(): void {
    this.listeners.forEach((listener) => listener.remove());
    this.listeners.clear();
  }

  isAvailable(): boolean {
    return SecureCardNativeModule !== null;
  }

  getConstants(): { [key: string]: any } {
    return SecureCardNativeModule.getConstants();
  }
}

export default new SecureCardNative();

export { useSecureCard } from "./hooks";
export {
  generateSecureToken,
  validateToken,
  generateMockToken,
  setSecretKey,
} from "./utils/tokenGenerator";
export * from "./types";
