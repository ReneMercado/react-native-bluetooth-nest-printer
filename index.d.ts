import * as React from "react";

export interface BluetoothProps {
  EVENT_DEVICE_ALREADY_PAIRED?: boolean;
  EVENT_DEVICE_FOUND?: boolean;
  EVENT_DEVICE_DISCOVER_DONE?: boolean;
  EVENT_CONNECTION_LOST?: boolean;
  EVENT_UNABLE_CONNECT?: boolean;
  EVENT_CONNECTED?: boolean;
  EVENT_BLUETOOTH_NOT_SUPPORT?: boolean;

  isBluetoothEnabled?: Promise<boolean>;
  enableBluetooth?: Function;
  disableBluetooth?: Function;
  scanDevices?: Promise<Function>;
  connect?: Promise<Function>;
  writeRaw?: (data: string) => Promise<void>;
}

export function BluetoothManager(props: BluetoothProps): any;

export interface WriteBitmapOptions {
  /** Barcode / order code (drawn as pseudo-barcode) */
  code?: string;
  /** Text lines below barcode */
  lines?: string[];
  /** Label width in mm */
  widthMm: number;
  /** Label height in mm */
  heightMm: number;
  /** Dots per mm (~8 for 203 DPI). Default 8 */
  dotsPerMm?: number;
  /** Invert raster for white background / black text. Default true */
  invert?: boolean;
  /** Code format. Currently only QR is supported in bitmap labels. */
  codeFormat?: "qr";
  /** QR error correction level (L, M, Q, H). Default M. */
  qrEcc?: "L" | "M" | "Q" | "H";
  /** Desired folio font size in printer dots (raster). */
  folioFontSizeDots?: number;
  /** Desired QR size (square) in printer dots (raster). */
  qrSizeDots?: number;
  /** Optional 1-bit logo raster (base64); width must match label widthBytes */
  logoRasterBase64?: string;
  /** Logo width in bytes (must equal ceil(widthMm*dotsPerMm/8)) */
  logoWidthBytes?: number;
  /** Logo height in dots */
  logoHeightDots?: number;
}

/**
 * Build TSPL bitmap label and send via BLE. Reusable across apps (iOS & Android).
 */
export function writeBitmap(options: WriteBitmapOptions): Promise<void>;
