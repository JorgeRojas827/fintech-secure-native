import { useEffect, useCallback, useState } from "react";
import {
  OpenSecureViewParams,
  ValidationError,
  CloseEventData,
} from "../types";
import SecureCardNative from "../index";

interface UseSecureCardResult {
  openSecureView: (params: OpenSecureViewParams) => Promise<void>;
  closeSecureView: () => void;
  isOpening: boolean;
  isOpen: boolean;
  error: ValidationError | null;
  lastClosedData: CloseEventData | null;
}

export function useSecureCard(): UseSecureCardResult {
  const [isOpening, setIsOpening] = useState(false);
  const [isOpen, setIsOpen] = useState(false);
  const [error, setError] = useState<ValidationError | null>(null);
  const [lastClosedData, setLastClosedData] = useState<CloseEventData | null>(
    null
  );

  useEffect(() => {
    const unsubscribeOpened = SecureCardNative.onSecureViewOpened(() => {
      setIsOpen(true);
      setIsOpening(false);
    });

    const unsubscribeError = SecureCardNative.onValidationError(
      (err: ValidationError) => {
        setError(err);
        setIsOpening(false);
        setIsOpen(false);
      }
    );

    const unsubscribeClosed = SecureCardNative.onSecureViewClosed(
      (data: CloseEventData) => {
        setLastClosedData(data);
        setIsOpen(false);
      }
    );

    return () => {
      unsubscribeOpened();
      unsubscribeError();
      unsubscribeClosed();
    };
  }, []);

  const openSecureView = useCallback(async (params: OpenSecureViewParams) => {
    setIsOpening(true);
    setError(null);

    try {
      await SecureCardNative.openSecureView(params);
    } catch (err) {
      setIsOpening(false);
      throw err;
    }
  }, []);

  const closeSecureView = useCallback(() => {
    SecureCardNative.closeSecureView();
  }, []);

  return {
    openSecureView,
    closeSecureView,
    isOpening,
    isOpen,
    error,
    lastClosedData,
  };
}
