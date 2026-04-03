"use strict";

const { NativeModules } = require("react-native");
const { BluetoothManager } = NativeModules;

const BASE64_PREFIX = "BASE64:";
const BASE64_CHARS =
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

let QRCode;
try {
  // Dependency is expected to be provided by the host app.
  QRCode = require("qrcode");
} catch (e) {
  QRCode = null;
}

function asciiToBytes(text) {
  const bytes = new Uint8Array(text.length);
  for (let i = 0; i < text.length; i += 1) {
    bytes[i] = text.charCodeAt(i) & 0xff;
  }
  return bytes;
}

function concatBytes(...parts) {
  const total = parts.reduce((sum, part) => sum + part.length, 0);
  const out = new Uint8Array(total);
  let offset = 0;
  parts.forEach((part) => {
    out.set(part, offset);
    offset += part.length;
  });
  return out;
}

function bytesToBase64(bytes) {
  let output = "";
  let i = 0;
  for (; i + 2 < bytes.length; i += 3) {
    const triple = (bytes[i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2];
    output += BASE64_CHARS[(triple >> 18) & 0x3f];
    output += BASE64_CHARS[(triple >> 12) & 0x3f];
    output += BASE64_CHARS[(triple >> 6) & 0x3f];
    output += BASE64_CHARS[triple & 0x3f];
  }
  const remaining = bytes.length - i;
  if (remaining === 1) {
    const triple = bytes[i] << 16;
    output += BASE64_CHARS[(triple >> 18) & 0x3f];
    output += BASE64_CHARS[(triple >> 12) & 0x3f];
    output += "==";
  } else if (remaining === 2) {
    const triple = (bytes[i] << 16) | (bytes[i + 1] << 8);
    output += BASE64_CHARS[(triple >> 18) & 0x3f];
    output += BASE64_CHARS[(triple >> 12) & 0x3f];
    output += BASE64_CHARS[(triple >> 6) & 0x3f];
    output += "=";
  }
  return output;
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function normalizeBitmapText(value) {
  return (value || "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^A-Za-z0-9 .:/-]/g, "")
    .toUpperCase();
}

const FONT_5X7 = {
  " ": [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
  ".": [0x00, 0x00, 0x00, 0x00, 0x00, 0x0c, 0x0c],
  ":": [0x00, 0x0c, 0x0c, 0x00, 0x0c, 0x0c, 0x00],
  "/": [0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40],
  "-": [0x00, 0x00, 0x00, 0x3e, 0x00, 0x00, 0x00],
  "0": [0x1e, 0x21, 0x23, 0x25, 0x29, 0x31, 0x1e],
  "1": [0x04, 0x0c, 0x14, 0x04, 0x04, 0x04, 0x1f],
  "2": [0x1e, 0x21, 0x01, 0x02, 0x0c, 0x10, 0x3f],
  "3": [0x1e, 0x21, 0x01, 0x0e, 0x01, 0x21, 0x1e],
  "4": [0x02, 0x06, 0x0a, 0x12, 0x3f, 0x02, 0x02],
  "5": [0x3f, 0x20, 0x3e, 0x01, 0x01, 0x21, 0x1e],
  "6": [0x0e, 0x10, 0x20, 0x3e, 0x21, 0x21, 0x1e],
  "7": [0x3f, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08],
  "8": [0x1e, 0x21, 0x21, 0x1e, 0x21, 0x21, 0x1e],
  "9": [0x1e, 0x21, 0x21, 0x1f, 0x01, 0x02, 0x1c],
  A: [0x0e, 0x11, 0x11, 0x1f, 0x11, 0x11, 0x11],
  B: [0x1e, 0x11, 0x11, 0x1e, 0x11, 0x11, 0x1e],
  C: [0x0e, 0x11, 0x10, 0x10, 0x10, 0x11, 0x0e],
  D: [0x1e, 0x11, 0x11, 0x11, 0x11, 0x11, 0x1e],
  E: [0x1f, 0x10, 0x10, 0x1e, 0x10, 0x10, 0x1f],
  F: [0x1f, 0x10, 0x10, 0x1e, 0x10, 0x10, 0x10],
  G: [0x0e, 0x11, 0x10, 0x17, 0x11, 0x11, 0x0e],
  H: [0x11, 0x11, 0x11, 0x1f, 0x11, 0x11, 0x11],
  I: [0x1f, 0x04, 0x04, 0x04, 0x04, 0x04, 0x1f],
  J: [0x07, 0x02, 0x02, 0x02, 0x12, 0x12, 0x0c],
  K: [0x11, 0x12, 0x14, 0x18, 0x14, 0x12, 0x11],
  L: [0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x1f],
  M: [0x11, 0x1b, 0x15, 0x15, 0x11, 0x11, 0x11],
  N: [0x11, 0x19, 0x15, 0x13, 0x11, 0x11, 0x11],
  O: [0x0e, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0e],
  P: [0x1e, 0x11, 0x11, 0x1e, 0x10, 0x10, 0x10],
  Q: [0x0e, 0x11, 0x11, 0x11, 0x15, 0x12, 0x0d],
  R: [0x1e, 0x11, 0x11, 0x1e, 0x14, 0x12, 0x11],
  S: [0x0f, 0x10, 0x10, 0x0e, 0x01, 0x01, 0x1e],
  T: [0x1f, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04],
  U: [0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0e],
  V: [0x11, 0x11, 0x11, 0x11, 0x11, 0x0a, 0x04],
  W: [0x11, 0x11, 0x11, 0x15, 0x15, 0x15, 0x0a],
  X: [0x11, 0x11, 0x0a, 0x04, 0x0a, 0x11, 0x11],
  Y: [0x11, 0x11, 0x0a, 0x04, 0x04, 0x04, 0x04],
  Z: [0x1f, 0x01, 0x02, 0x04, 0x08, 0x10, 0x1f],
  "?": [0x1e, 0x21, 0x02, 0x04, 0x04, 0x00, 0x04],
};

function setPixel(buffer, widthBytes, widthDots, heightDots, x, y) {
  if (x < 0 || y < 0 || x >= widthDots || y >= heightDots) return;
  const byteIndex = y * widthBytes + (x >> 3);
  const bit = 0x80 >> (x & 7);
  buffer[byteIndex] |= bit;
}

function fillRect(buffer, widthBytes, widthDots, heightDots, x, y, w, h) {
  for (let yy = y; yy < y + h; yy += 1) {
    for (let xx = x; xx < x + w; xx += 1) {
      setPixel(buffer, widthBytes, widthDots, heightDots, xx, yy);
    }
  }
}

function drawTextLine(buffer, widthBytes, widthDots, heightDots, x, y, text, scale) {
  const safe = normalizeBitmapText(text);
  let cursorX = x;
  const charWidth = 5;
  const charHeight = 7;
  const spacing = 1;
  for (const char of safe) {
    const glyph = FONT_5X7[char] || FONT_5X7["?"];
    for (let row = 0; row < charHeight; row += 1) {
      const rowBits = glyph[row];
      for (let col = 0; col < charWidth; col += 1) {
        if (rowBits & (1 << (charWidth - 1 - col))) {
          fillRect(
            buffer,
            widthBytes,
            widthDots,
            heightDots,
            cursorX + col * scale,
            y + row * scale,
            scale,
            scale
          );
        }
      }
    }
    cursorX += (charWidth + spacing) * scale;
  }
}

function drawPseudoBarcode(
  buffer,
  widthBytes,
  widthDots,
  heightDots,
  x,
  y,
  width,
  height,
  code
) {
  let cursorX = x + 2;
  let isBlack = true;
  for (const char of code) {
    const val = char.charCodeAt(0);
    const barWidth = 1 + (val % 4);
    if (isBlack) {
      fillRect(buffer, widthBytes, widthDots, heightDots, cursorX, y, barWidth, height);
    }
    cursorX += barWidth;
    isBlack = !isBlack;
    if (cursorX >= x + width - 2) break;
  }
}

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

function getQrModules(value, errorCorrectionLevel) {
  if (!QRCode || typeof QRCode.create !== "function") {
    throw new Error(
      "qrcode dependency is required to render QR bitmap labels"
    );
  }

  const qr = QRCode.create(String(value || ""), {
    errorCorrectionLevel: errorCorrectionLevel || "M",
  });

  return {
    size: qr.modules.size,
    data: qr.modules.data,
  };
}

function drawQrCode(
  buffer,
  widthBytes,
  widthDots,
  heightDots,
  x,
  y,
  boxSizeDots,
  value,
  errorCorrectionLevel
) {
  if (boxSizeDots <= 0) return false;

  let modules;
  try {
    modules = getQrModules(value, errorCorrectionLevel);
  } catch (e) {
    return false;
  }

  const quietZoneModules = 4;
  const moduleCount = modules.size;
  const totalModules = moduleCount + quietZoneModules * 2;
  const moduleSize = Math.floor(boxSizeDots / totalModules);
  if (moduleSize <= 0) return false;

  const renderedSize = moduleSize * totalModules;
  const offsetX =
    x +
    Math.floor((boxSizeDots - renderedSize) / 2) +
    quietZoneModules * moduleSize;
  const offsetY =
    y +
    Math.floor((boxSizeDots - renderedSize) / 2) +
    quietZoneModules * moduleSize;

  for (let row = 0; row < moduleCount; row += 1) {
    for (let col = 0; col < moduleCount; col += 1) {
      const idx = row * moduleCount + col;
      if (modules.data[idx]) {
        fillRect(
          buffer,
          widthBytes,
          widthDots,
          heightDots,
          offsetX + col * moduleSize,
          offsetY + row * moduleSize,
          moduleSize,
          moduleSize
        );
      }
    }
  }

  return true;
}

function decodeBase64ToBytes(base64) {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i) & 0xff;
  }
  return bytes;
}

/**
 * Build TSPL bitmap payload and send via BluetoothManager.writeRaw.
 * Works on both iOS and Android (BLE); payload is sent as BASE64 for binary raster.
 *
 * @param {Object} options
 * @param {string} [options.code='CODE'] - Barcode / order code (drawn as pseudo-barcode)
 * @param {string[]} [options.lines=[]] - Text lines below barcode
 * @param {number} options.widthMm - Label width in mm
 * @param {number} options.heightMm - Label height in mm
 * @param {number} [options.dotsPerMm=8] - Dots per mm (~8 for 203 DPI)
 * @param {boolean} [options.invert=true] - If true, invert raster for white background / black text
 * @param {string} [options.codeFormat='qr'] - Code format. Currently only QR is supported.
 * @param {'L'|'M'|'Q'|'H'} [options.qrEcc='M'] - QR error correction level.
 * @param {number} [options.folioFontSizeDots] - Desired folio height in printer dots.
 * @param {number} [options.qrSizeDots] - Desired QR box size (square) in printer dots.
 * @param {string} [options.logoRasterBase64] - Optional 1-bit logo raster (base64), same width as label
 * @param {number} [options.logoWidthBytes] - Logo width in bytes (must equal widthBytes)
 * @param {number} [options.logoHeightDots] - Logo height in dots
 * @returns {Promise<void>}
 */
async function writeBitmap(options) {
  const {
    code = "CODE",
    lines = [],
    widthMm,
    heightMm,
    dotsPerMm = 8,
    invert = true,
    codeFormat = "qr",
    qrEcc = "M",
    folioFontSizeDots,
    qrSizeDots,
    logoRasterBase64,
    logoWidthBytes,
    logoHeightDots,
  } = options;

  if (widthMm == null || heightMm == null) {
    return Promise.reject(new Error("writeBitmap requires widthMm and heightMm"));
  }

  const widthDots = Math.round(widthMm * dotsPerMm);
  const heightDots = Math.round(heightMm * dotsPerMm);
  const widthBytes = Math.ceil(widthDots / 8);
  const buffer = new Uint8Array(widthBytes * heightDots);

  const mmToDots = (mm) => Math.round(mm * dotsPerMm);
  const marginDots = mmToDots(4);
  const hasLogo =
    logoRasterBase64 &&
    logoWidthBytes != null &&
    logoHeightDots != null &&
    logoWidthBytes === widthBytes &&
    logoHeightDots > 0 &&
    logoHeightDots < heightDots;
  const contentAreaTop = hasLogo ? logoHeightDots + mmToDots(2) : 0;

  if (hasLogo) {
    try {
      const logoBytes = decodeBase64ToBytes(logoRasterBase64);
      const logoSize = logoWidthBytes * logoHeightDots;
      const copyLen = Math.min(logoSize, logoBytes.length, widthBytes * logoHeightDots);
      for (let i = 0; i < copyLen; i += 1) {
        buffer[i] = logoBytes[i];
      }
    } catch (e) {
      // ignore invalid logo, continue without it
    }
  }

  const availableWidth = widthDots - marginDots * 2;
  const bottomLimit = heightDots - marginDots;

  const linesList = Array.isArray(lines)
    ? lines
        .map((line) => String(line ?? ""))
        .filter(Boolean)
        .slice(0, 8)
    : [];

  let cursorY = contentAreaTop + marginDots;

  if (String(codeFormat).toLowerCase() === "qr") {
    const desiredQrSizeDots =
      typeof qrSizeDots === "number" && qrSizeDots > 0
        ? Math.round(qrSizeDots)
        : Math.min(availableWidth, bottomLimit - cursorY);
    const maxQrSizeDots = Math.max(1, Math.min(availableWidth, bottomLimit - cursorY));
    const qrBoxSize = clamp(desiredQrSizeDots, 1, maxQrSizeDots);
    const qrX = Math.max(marginDots, Math.floor((widthDots - qrBoxSize) / 2));
    const qrOk = drawQrCode(
      buffer,
      widthBytes,
      widthDots,
      heightDots,
      qrX,
      cursorY,
      qrBoxSize,
      String(code),
      qrEcc
    );
    if (!qrOk) {
      drawPseudoBarcode(
        buffer,
        widthBytes,
        widthDots,
        heightDots,
        marginDots,
        cursorY,
        availableWidth,
        Math.max(1, Math.floor(qrBoxSize * 0.35)),
        String(code)
      );
    }
    cursorY += qrBoxSize + mmToDots(2);
  } else {
    const barcodeHeightMm = Math.min(30, Math.max(12, heightMm * 0.4));
    const barcodeHeightDots = mmToDots(barcodeHeightMm);
    drawPseudoBarcode(
      buffer,
      widthBytes,
      widthDots,
      heightDots,
      marginDots,
      cursorY,
      availableWidth,
      barcodeHeightDots,
      String(code)
    );
    cursorY += barcodeHeightDots + mmToDots(2);
  }

  const folioLine = linesList[0] || "";
  const infoLines = linesList.slice(1);

  if (folioLine && cursorY < bottomLimit) {
    const safeFolio = normalizeBitmapText(folioLine);
    const desiredScale =
      typeof folioFontSizeDots === "number" && folioFontSizeDots > 0
        ? Math.max(1, Math.round(folioFontSizeDots / 7))
        : 3;
    const folioLen = Math.max(1, safeFolio.length);
    const maxScaleByWidth = Math.max(1, Math.floor(availableWidth / (folioLen * 6)));
    const maxScaleByHeight = Math.max(1, Math.floor((bottomLimit - cursorY) / 7));
    const folioScale = Math.max(
      1,
      Math.min(desiredScale, maxScaleByWidth, maxScaleByHeight)
    );

    const maxFolioChars = Math.max(1, Math.floor(availableWidth / (6 * folioScale)));
    const trimmedFolio = safeFolio.slice(0, maxFolioChars);
    const folioWidthDots = trimmedFolio.length * 6 * folioScale;
    const folioX = Math.max(
      marginDots,
      Math.floor((widthDots - folioWidthDots) / 2)
    );
    drawTextLine(
      buffer,
      widthBytes,
      widthDots,
      heightDots,
      folioX,
      cursorY,
      trimmedFolio,
      folioScale
    );

    cursorY += 7 * folioScale + mmToDots(1);

    if (infoLines.length > 0 && cursorY < bottomLimit) {
      const maxInfoLen = Math.max(
        1,
        ...infoLines.map((line) => normalizeBitmapText(String(line)).length)
      );
      const maxInfoScaleByWidth = Math.max(
        1,
        Math.floor(availableWidth / (maxInfoLen * 6))
      );
      let infoScale = clamp(Math.round(folioScale * 0.4), 1, 4);
      infoScale = Math.max(1, Math.min(infoScale, maxInfoScaleByWidth));
      let infoLineGap = infoScale * 8;
      let maxLinesFit = Math.floor((bottomLimit - cursorY) / infoLineGap);

      while (infoScale > 1 && maxLinesFit === 0) {
        infoScale -= 1;
        infoLineGap = infoScale * 8;
        maxLinesFit = Math.floor((bottomLimit - cursorY) / infoLineGap);
      }

      const maxInfoChars = Math.max(1, Math.floor(availableWidth / (6 * infoScale)));
      infoLines.slice(0, Math.max(0, maxLinesFit)).forEach((line, index) => {
        const safeLine = normalizeBitmapText(String(line)).slice(0, maxInfoChars);
        drawTextLine(
          buffer,
          widthBytes,
          widthDots,
          heightDots,
          marginDots,
          cursorY + index * infoLineGap,
          safeLine,
          infoScale
        );
      });
    }
  }

  if (invert) {
    for (let i = 0; i < buffer.length; i += 1) {
      buffer[i] = 0xff ^ buffer[i];
    }
  }

  const widthMmInt = Math.round(widthMm);
  const heightMmInt = Math.round(heightMm);
  const headerLines = [
    "DENSITY 11",
    "SPEED 4",
    "REFERENCE 0,0",
    "OFFSET 0 mm",
    `SIZE ${widthMmInt} mm,${heightMmInt} mm`,
    "GAP 3 mm,0 mm",
    "DIRECTION 0,0",
    "CLS",
    `BITMAP 0,0,${widthBytes},${heightDots},0,`,
  ];
  const header = headerLines.join("\r\n") + "\r\n";
  const footer = "\r\nPRINT 1,1\r\n";
  const payloadBytes = concatBytes(
    asciiToBytes(header),
    buffer,
    asciiToBytes(footer)
  );
  const payload = BASE64_PREFIX + bytesToBase64(payloadBytes);

  return BluetoothManager.writeRaw(payload);
}

module.exports = { writeBitmap };
