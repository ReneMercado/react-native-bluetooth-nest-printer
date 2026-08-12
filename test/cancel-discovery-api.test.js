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

function getIosExportedMethod(source, signature) {
  const methodStart = source.indexOf(signature);
  assert.notEqual(methodStart, -1, `Missing iOS method: ${signature}`);
  const nextMethod = source.indexOf("RCT_EXPORT_METHOD(", methodStart + 1);
  return source.slice(methodStart, nextMethod === -1 ? source.length : nextMethod);
}

test("Android cancelDiscovery reuses discovery cancellation without changing connection or pairing", () => {
  const source = read(
    "android/src/main/java/cn/jystudio/bluetooth/RNBluetoothManagerModule.java"
  );
  const method = getJavaMethod(source, "public void cancelDiscovery");

  assert.match(method, /cancelDisCovery\(\)/);
  assert.match(method, /promise\.resolve\(null\)/);
  assert.match(method, /CANCEL_DISCOVERY_FAILED/);
  assert.doesNotMatch(
    method,
    /mService\.(disconnect|stop)|removeBond|unpairDevice|disable\(/
  );
});

test("Android scan cancellation still lets ACTION_DISCOVERY_FINISHED settle the pending scan", () => {
  const source = read(
    "android/src/main/java/cn/jystudio/bluetooth/RNBluetoothManagerModule.java"
  );
  const receiverStart = source.indexOf(
    "BluetoothAdapter.ACTION_DISCOVERY_FINISHED.equals(action)"
  );
  assert.notEqual(receiverStart, -1);
  const receiver = source.slice(receiverStart, source.indexOf("private void emitRNEvent", receiverStart));

  assert.match(receiver, /promiseMap\.remove\(PROMISE_SCAN\)/);
  assert.match(receiver, /result\.put\("paired", pairedDeivce\)/);
  assert.match(receiver, /result\.put\("found", foundDevice\)/);
  assert.match(receiver, /promise\.resolve\(result\.toString\(\)\)/);
});

test("iOS cancelDiscovery stops scanning without disconnecting the connected peripheral", () => {
  const source = read("ios/RNBluetoothManager.m");
  const method = getIosExportedMethod(
    source,
    "RCT_EXPORT_METHOD(cancelDiscovery:"
  );

  assert.match(method, /\[self callStop\]/);
  assert.match(method, /resolve\(nil\)/);
  assert.doesNotMatch(method, /cancelPeripheralConnection|connected\s*=\s*nil/);

  const stopHelperStart = source.indexOf("-(void)callStop");
  const stopHelper = source.slice(
    stopHelperStart,
    source.indexOf("- (void) initSupportServices", stopHelperStart)
  );
  assert.match(stopHelper, /stopScan/);
  assert.match(stopHelper, /scanResolveBlock/);
});

test("TypeScript declarations and README expose cancelDiscovery semantics", () => {
  const declarations = read("index.d.ts");
  assert.match(declarations, /cancelDiscovery\(\):\s*Promise<void>/);

  const readme = read("README.md");
  assert.match(readme, /BluetoothManager\.cancelDiscovery\(\)/);
  assert.match(readme, /does not disconnect|without disconnecting/i);
  assert.match(readme, /does not unpair|without unpairing/i);
  assert.match(readme, /before .*connect/i);
});
