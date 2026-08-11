const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const repositoryRoot = path.resolve(__dirname, "..");
const androidModulePath = path.join(
  repositoryRoot,
  "android/src/main/java/cn/jystudio/bluetooth/RNBluetoothManagerModule.java"
);

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

test("getPairedDevices resolves bonded devices without discovery", () => {
  const source = readFileSync(androidModulePath, "utf8");
  const method = getJavaMethod(source, "public void getPairedDevices");

  assert.match(method, /getBluetoothAdapter\(\)/);
  assert.match(method, /EVENT_BLUETOOTH_NOT_SUPPORT/);
  assert.match(method, /isEnabled\(\)/);
  assert.match(method, /BT NOT ENABLED/);
  assert.match(method, /getBondedDevices\(\)/);
  assert.match(method, /promise\.resolve\(/);
  assert.doesNotMatch(method, /startDiscovery\(/);
});

test("getPairedDevices rejects missing Android Bluetooth permission", () => {
  const source = readFileSync(androidModulePath, "utf8");
  const method = getJavaMethod(source, "public void getPairedDevices");

  assert.match(method, /catch\s*\(SecurityException/);
  assert.match(method, /BLUETOOTH_CONNECT_PERMISSION_REQUIRED/);

  const manifest = read("android/src/main/AndroidManifest.xml");
  assert.match(manifest, /android\.permission\.BLUETOOTH_CONNECT/);
});

test("paired devices use native maps while scanDevices remains compatible", () => {
  const source = readFileSync(androidModulePath, "utf8");
  const serializer = getJavaMethod(
    source,
    "private WritableArray pairedDevicesToWritableArray"
  );
  const scanDevices = getJavaMethod(source, "public void scanDevices");

  assert.match(serializer, /Arguments\.createArray\(\)/);
  assert.match(serializer, /Arguments\.createMap\(\)/);
  assert.match(serializer, /putString\("address"/);
  assert.match(serializer, /putNull\("name"\)/);
  assert.match(scanDevices, /EVENT_DEVICE_ALREADY_PAIRED/);
  assert.match(scanDevices, /startDiscovery\(\)/);
});

test("TypeScript and README expose the Android-only API", () => {
  const declarations = read("index.d.ts");
  assert.match(declarations, /interface BluetoothDevice\s*{/);
  assert.match(declarations, /name:\s*string\s*\|\s*null/);
  assert.match(declarations, /address:\s*string/);
  assert.match(
    declarations,
    /getPairedDevices\(\):\s*Promise<BluetoothDevice\[\]>/
  );

  const readme = read("README.md");
  assert.match(readme, /getPairedDevices/);
  assert.match(readme, /Android only/i);
  assert.match(readme, /without (running|starting) (a )?discovery scan/i);
  assert.match(readme, /BLUETOOTH_CONNECT/);
});
