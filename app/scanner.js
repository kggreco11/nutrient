import { Capacitor } from "@capacitor/core";
export async function scanNative() {
  const { CapacitorBarcodeScanner, CapacitorBarcodeScannerTypeHint } =
    await import("@capacitor/barcode-scanner");
  const result = await CapacitorBarcodeScanner.scanBarcode({
    hint: CapacitorBarcodeScannerTypeHint.ALL,
    cameraDirection: 1,
    scanInstructions: "Center the package barcode in the frame",
    scanButton: false,
    cancelButtonAccessibilityLabel: "Cancel barcode scan",
    torchButtonOnAccessibilityLabel: "Turn torch off",
    torchButtonOffAccessibilityLabel: "Turn torch on",
  });
  return result.ScanResult;
}
export const isNative = () => Capacitor.isNativePlatform();
export function cameraError(error) {
  return error.name === "NotAllowedError"
    ? "Camera access was denied. Allow camera access in your device settings, or enter the barcode manually."
    : error.name === "NotFoundError"
      ? "No camera was found on this device. You can enter the barcode manually."
      : error.name === "NotReadableError"
        ? "The camera is in use by another app. Close it and try again."
        : error.message ||
          "The camera could not be started. Try again or enter the barcode manually.";
}
export async function startWebScanner(video, onResult, onError) {
  if (!navigator.mediaDevices?.getUserMedia)
    throw Error(
      "Camera scanning requires HTTPS or localhost and a camera-enabled browser.",
    );
  const { BrowserMultiFormatReader } = await import("@zxing/browser");
  const reader = new BrowserMultiFormatReader();
  let stopped = false,
    controls;
  const stop = () => {
    stopped = true;
    controls?.stop();
    video.srcObject?.getTracks?.().forEach((t) => t.stop());
    video.srcObject = null;
  };
  const ready = reader
    .decodeFromConstraints(
      { video: { facingMode: { ideal: "environment" } }, audio: false },
      video,
      (result, error, c) => {
        controls = c;
        if (stopped) {
          c.stop();
          return;
        }
        if (result && /^\d{8,14}$/.test(result.getText())) {
          stop();
          onResult(result.getText());
        }
      },
    )
    .then((c) => {
      controls = c;
      if (stopped) c.stop();
    })
    .catch((e) => {
      stop();
      onError(e);
    });
  return { stop, ready };
}
