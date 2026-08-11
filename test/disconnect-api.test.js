const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const repositoryRoot = path.resolve(__dirname, "..");

function read(relativePath) {
  return readFileSync(path.join(repositoryRoot, relativePath), "utf8");
}

function getJavaMethod(source, signature) {
  const signatureIndex = source.indexOf(signature);
  assert.notEqual(signatureIndex, -1, `Missing Java method: ${signature}`);

  const openingBraceIndex = source.indexOf("{", signatureIndex);
  assert.notEqual(openingBraceIndex, -1, `Missing method body: ${signature}`);

  let depth = 0;
  for (let index = openingBraceIndex; index < source.length; index += 1) {
    if (source[index] === "{") depth += 1;
    if (source[index] === "}") depth -= 1;
    if (depth === 0) return source.slice(signatureIndex, index + 1);
  }

  assert.fail(`Unterminated Java method: ${signature}`);
}

test("Android disconnect closes the active socket without removing the bond", () => {
  const moduleSource = read(
    "android/src/main/java/cn/jystudio/bluetooth/RNBluetoothManagerModule.java"
  );
  const moduleMethod = getJavaMethod(moduleSource, "public void disconnect");
  assert.match(moduleMethod, /mService\.disconnect\(\)/);
  assert.match(moduleMethod, /promise\.resolve\(null\)/);
  assert.doesNotMatch(moduleMethod, /removeBond|unpairDevice|disable\(/);

  const serviceSource = read(
    "android/src/main/java/cn/jystudio/bluetooth/BluetoothService.java"
  );
  const serviceMethod = getJavaMethod(serviceSource, "public synchronized void disconnect");
  assert.match(serviceMethod, /mConnectedThread\.cancel\(\)/);
  assert.match(serviceMethod, /setState\(STATE_NONE/);
});

test("iOS disconnect cancels the active peripheral and clears cached session state", () => {
  const source = read("ios/RNBluetoothManager.m");
  assert.match(source, /RCT_EXPORT_METHOD\(disconnect:/);

  const methodStart = source.indexOf("RCT_EXPORT_METHOD(disconnect:");
  const nextMethod = source.indexOf("RCT_EXPORT_METHOD(", methodStart + 1);
  const method = source.slice(
    methodStart,
    nextMethod === -1 ? source.length : nextMethod
  );

  assert.match(method, /cancelPeripheralConnection:connected/);
  assert.match(method, /clearCachedWriteCharacteristic\(\)/);
  assert.match(method, /resetWriteState\(\)/);
  assert.match(method, /connected = nil/);
  assert.match(method, /resolve\(nil\)/);
});

test("TypeScript declarations and README expose disconnect semantics", () => {
  const declarations = read("index.d.ts");
  assert.match(declarations, /disconnect\(\):\s*Promise<void>/);

  const readme = read("README.md");
  assert.match(readme, /BluetoothManager\.disconnect\(\)/);
  assert.match(readme, /keeps? the device paired|without unpairing/i);
});
