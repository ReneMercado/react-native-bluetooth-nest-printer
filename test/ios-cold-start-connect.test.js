const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const repositoryRoot = path.resolve(__dirname, "..");
const source = readFileSync(
  path.join(repositoryRoot, "ios/RNBluetoothManager.m"),
  "utf8"
);

function getMethod(signature) {
  const signatureIndex = source.indexOf(signature);
  assert.notEqual(signatureIndex, -1, `Missing iOS method: ${signature}`);

  const openingBraceIndex = source.indexOf("{", signatureIndex);
  assert.notEqual(
    openingBraceIndex,
    -1,
    `Missing method body: ${signature}`
  );

  let depth = 0;
  for (let index = openingBraceIndex; index < source.length; index += 1) {
    if (source[index] === "{") depth += 1;
    if (source[index] === "}") depth -= 1;
    if (depth === 0) return source.slice(signatureIndex, index + 1);
  }

  assert.fail(`Unterminated iOS method: ${signature}`);
}

function indexOfOrFail(value, pattern, message) {
  const index = value.search(pattern);
  assert.notEqual(index, -1, message || `Missing pattern: ${pattern}`);
  return index;
}

test("connect owns one pending Promise and delegates native work to the resume helper", () => {
  const method = getMethod("RCT_EXPORT_METHOD(connect:");
  const resolveOwner = indexOfOrFail(method, /self\.connectResolveBlock\s*=\s*resolve/);
  const rejectOwner = indexOfOrFail(method, /self\.connectRejectBlock\s*=\s*reject/);
  const pendingAddress = indexOfOrFail(method, /pendingConnectAddress\s*=\s*\[address copy\]/);
  const resume = indexOfOrFail(method, /\[self resumePendingConnectionIfPossible\]/);

  assert.ok(resolveOwner < resume);
  assert.ok(rejectOwner < resume);
  assert.ok(pendingAddress < resume);
  assert.doesNotMatch(method, /scanForPeripheralsWithServices|connectPeripheral:/);
  assert.match(method, /CONNECT_IN_PROGRESS/);
});

test("transitional CoreBluetooth states preserve the pending request without starting work", () => {
  const method = getMethod("- (void)resumePendingConnectionIfPossible");
  const unknown = indexOfOrFail(method, /CBManagerStateUnknown/);
  const resetting = indexOfOrFail(method, /CBManagerStateResetting/);
  const poweredOn = indexOfOrFail(method, /CBManagerStatePoweredOn/);

  assert.ok(unknown < poweredOn);
  assert.ok(resetting < poweredOn);
  assert.match(method, /RNBluetoothPendingConnectPhaseWaitingForBluetooth/);
  assert.match(method, /return;/);
  assert.match(method, /pendingConnectTimeoutTimer[\s\S]*invalidate/);
  assert.doesNotMatch(
    method.slice(Math.min(unknown, resetting), poweredOn),
    /scanForPeripheralsWithServices|connectPeripheral:/
  );
});

test("a resetting manager discards stale transport state before later resuming", () => {
  const method = getMethod("- (void)resumePendingConnectionIfPossible");
  const resettingStart = indexOfOrFail(
    method,
    /if\s*\(state\s*==\s*CBManagerStateResetting\)/
  );
  const resettingBranch = method.slice(
    resettingStart,
    indexOfOrFail(method.slice(resettingStart), /if\s*\(state\s*==\s*CBManagerStateUnknown\)/) + resettingStart
  );

  assert.match(resettingBranch, /pendingConnectPeripheral\s*=\s*nil/);
  assert.match(resettingBranch, /connected\s*=\s*nil/);
  assert.match(resettingBranch, /clearCachedWriteCharacteristic\(\)/);
  assert.match(resettingBranch, /clearPendingConnectWarmup\(\)/);
});

test("centralManagerDidUpdateState resumes the original pending request", () => {
  const method = getMethod("- (void)centralManagerDidUpdateState:");

  assert.match(method, /\[self resumePendingConnectionIfPossible\]/);
  assert.doesNotMatch(method, /RCT_EXPORT_METHOD|connect:.*findEventsWithResolver/);
});

test("saved UUID retrieval is attempted before scan fallback", () => {
  const method = getMethod("- (void)resumePendingConnectionIfPossible");
  const uuid = indexOfOrFail(method, /\[\[NSUUID alloc\] initWithUUIDString:pendingConnectAddress\]/);
  const retrieve = indexOfOrFail(method, /retrievePeripheralsWithIdentifiers:@\[uuid\]/);
  const scan = indexOfOrFail(method, /scanForPeripheralsWithServices:nil/);

  assert.ok(uuid < retrieve);
  assert.ok(retrieve < scan);
});

test("a retrieved peripheral follows the normal connectPeripheral callback path", () => {
  const method = getMethod("- (void)resumePendingConnectionIfPossible");

  assert.match(method, /retrievedPeripherals\s+firstObject/);
  assert.match(method, /pendingConnectPeripheral\s*=\s*peripheral/);
  assert.match(method, /RNBluetoothPendingConnectPhaseConnecting/);
  assert.match(method, /connectPeripheral:peripheral\s+options:nil/);
  assert.doesNotMatch(method, /peripheral\.state\s*==\s*CBPeripheralStateConnected/);
});

test("missing retrieval falls back to a single UUID discovery scan", () => {
  const method = getMethod("- (void)resumePendingConnectionIfPossible");
  const fallback = indexOfOrFail(method, /if\s*\(!peripheral\)/);
  const scanning = indexOfOrFail(
    method,
    /pendingConnectPhase\s*=\s*RNBluetoothPendingConnectPhaseScanning/
  );
  const scan = indexOfOrFail(method, /scanForPeripheralsWithServices:nil/);

  assert.ok(fallback < scanning);
  assert.ok(scanning < scan);
});

test("the same connected peripheral resolves without reconnecting", () => {
  const method = getMethod("- (void)resumePendingConnectionIfPossible");
  const samePeripheral = indexOfOrFail(
    method,
    /\[connected\.identifier\.UUIDString isEqualToString:pendingConnectAddress\]/
  );
  const resolve = indexOfOrFail(method, /resolveBlock\(nil\)/);
  const handoff = indexOfOrFail(
    method,
    /pendingConnectPhase\s*=\s*RNBluetoothPendingConnectPhaseWaitingForPreviousDisconnect/
  );

  assert.ok(samePeripheral < resolve);
  assert.ok(resolve < handoff);
});

test("switching peripherals waits for singleton transport handoff", () => {
  const resume = getMethod("- (void)resumePendingConnectionIfPossible");
  const disconnect = getMethod(
    "- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:"
  );

  assert.match(
    resume,
    /pendingConnectPhase\s*=\s*RNBluetoothPendingConnectPhaseWaitingForPreviousDisconnect[\s\S]*cancelPeripheralConnection:connected/
  );
  assert.match(
    disconnect,
    /RNBluetoothPendingConnectPhaseWaitingForPreviousDisconnect[\s\S]*pendingConnectPhase\s*=\s*RNBluetoothPendingConnectPhaseIdle[\s\S]*resumePendingConnectionIfPossible/
  );
});

test("terminal CoreBluetooth states reject and clear the pending connect", () => {
  const method = getMethod("- (void)resumePendingConnectionIfPossible");

  assert.match(method, /CBManagerStatePoweredOff[\s\S]*BLUETOOTH_POWERED_OFF/);
  assert.match(method, /CBManagerStateUnauthorized[\s\S]*BLUETOOTH_UNAUTHORIZED/);
  assert.match(method, /CBManagerStateUnsupported[\s\S]*BLUETOOTH_UNSUPPORTED/);
  assert.match(method, /rejectPendingConnectForPeripheral/);
});

test("disconnect cancels a cold-start request through centralized Promise cleanup", () => {
  const method = getMethod("RCT_EXPORT_METHOD(disconnect:");

  assert.match(method, /rejectPendingConnectForPeripheral/);
  assert.match(method, /CONNECT_CANCELLED/);
  assert.doesNotMatch(method, /self\.connectRejectBlock\s*\(/);
  assert.match(method, /cancelPeripheralConnection:connected/);
  assert.match(method, /resetWriteState\(\)/);
});

test("pending phases and cleanup prevent duplicate starts or Promise settlement", () => {
  const resume = getMethod("- (void)resumePendingConnectionIfPossible");
  const resolve = getMethod("- (void)resolveConnectWhenWritableReady:");
  const reject = getMethod("- (void)rejectPendingConnectForPeripheral:");

  for (const phase of [
    "WaitingForPreviousDisconnect",
    "Scanning",
    "Connecting",
    "RetryScheduled",
    "DiscoveringWritable",
  ]) {
    assert.match(resume, new RegExp(`RNBluetoothPendingConnectPhase${phase}`));
  }

  const resolveCleanup = indexOfOrFail(resolve, /clearPendingConnectRequest/);
  const resolveCall = indexOfOrFail(resolve, /resolveBlock\(nil\)/);
  const rejectCleanup = indexOfOrFail(reject, /clearPendingConnectRequest/);
  const rejectCall = indexOfOrFail(reject, /rejectBlock\(/);

  assert.ok(resolveCleanup < resolveCall);
  assert.ok(rejectCleanup < rejectCall);
});

test("didDiscoverPeripheral connects the matching scanning request only once", () => {
  const method = getMethod(
    "- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:"
  );
  const scanning = indexOfOrFail(
    method,
    /pendingConnectPhase\s*==\s*RNBluetoothPendingConnectPhaseScanning/
  );
  const connecting = indexOfOrFail(
    method,
    /pendingConnectPhase\s*=\s*RNBluetoothPendingConnectPhaseConnecting/
  );
  const connect = indexOfOrFail(method, /connectPeripheral:peripheral\s+options:nil/);

  assert.ok(scanning < connecting);
  assert.ok(connecting < connect);
  assert.equal((method.match(/connectPeripheral:peripheral\s+options:nil/g) || []).length, 1);
});

test("didConnectPeripheral preserves the request through writable warmup", () => {
  const didConnect = getMethod(
    "- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:"
  );
  const characteristics = getMethod(
    "- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:"
  );

  assert.match(
    didConnect,
    /pendingConnectPhase\s*=\s*RNBluetoothPendingConnectPhaseDiscoveringWritable/
  );
  assert.match(didConnect, /discoverServices:nil/);
  assert.doesNotMatch(didConnect, /pendingConnectAddress\s*=\s*nil/);
  assert.match(characteristics, /resolveConnectWhenWritableReady/);
});

test("service discovery cannot bypass centralized writable-ready settlement", () => {
  const method = getMethod(
    "- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:"
  );

  assert.doesNotMatch(method, /RCTPromiseResolveBlock|RCTPromiseRejectBlock/);
  assert.doesNotMatch(
    method,
    /self\.connectResolveBlock\s*=|self\.connectRejectBlock\s*=/
  );
  assert.match(method, /rejectPendingConnectForPeripheral/);
});

test("stale didConnect callbacks cannot revive a cancelled or timed-out request", () => {
  const method = getMethod(
    "- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:"
  );
  const matchingRequest = indexOfOrFail(method, /BOOL isCurrentPendingAttempt/);
  const guard = indexOfOrFail(method, /if\s*\(!isCurrentPendingAttempt\)/);
  const assignConnected = indexOfOrFail(method, /connected\s*=\s*peripheral/);

  assert.ok(matchingRequest < guard);
  assert.ok(guard < assignConnected);
  assert.match(method, /cancelPeripheralConnection:peripheral/);
});

test("stale didDisconnect callbacks cannot clear a newer connection attempt", () => {
  const method = getMethod(
    "- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:"
  );
  const activeCheck = indexOfOrFail(method, /BOOL disconnectedActivePeripheral/);
  const pendingCheck = indexOfOrFail(method, /BOOL disconnectedPendingPeripheral/);
  const staleGuard = indexOfOrFail(method, /if\s*\(!disconnectedActivePeripheral\s*&&\s*!disconnectedPendingPeripheral\)/);
  const clearWarmup = indexOfOrFail(method, /clearPendingConnectWarmup\(\)/);

  assert.ok(activeCheck < staleGuard);
  assert.ok(pendingCheck < staleGuard);
  assert.ok(staleGuard < clearWarmup);
});

test("disconnect callbacks during a transitional manager state keep the Promise pending", () => {
  const method = getMethod(
    "- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:"
  );
  const transitional = indexOfOrFail(
    method,
    /CBManagerStateUnknown[\s\S]*CBManagerStateResetting/
  );
  const rejection = indexOfOrFail(method, /rejectPendingConnectForPeripheral/);

  assert.ok(transitional < rejection);
  assert.match(
    method.slice(transitional, rejection),
    /RNBluetoothPendingConnectPhaseWaitingForBluetooth[\s\S]*return;/
  );
});

test("callStop settles discovery without erasing or settling a pending connection", () => {
  const method = getMethod("-(void)callStop");

  assert.match(method, /stopScan/);
  assert.match(method, /scanResolveBlock/);
  assert.match(method, /resumePendingConnectionIfPossible/);
  assert.doesNotMatch(method, /clearPendingConnectRequest/);
  assert.doesNotMatch(
    method,
    /connectResolveBlock\s*=\s*nil|connectRejectBlock\s*=\s*nil|connectResolveBlock\s*\(|connectRejectBlock\s*\(/
  );
});

test("active pending connections have a bounded native timeout", () => {
  const startTimeout = getMethod("- (void)startPendingConnectTimeoutIfNeeded");
  const timeout = getMethod("- (void)onPendingConnectTimeout");
  const resume = getMethod("- (void)resumePendingConnectionIfPossible");

  assert.match(startTimeout, /pendingConnectTimeoutInterval/);
  assert.match(timeout, /CONNECT_TIMEOUT/);
  assert.match(timeout, /rejectPendingConnectForPeripheral/);
  assert.match(resume, /CBManagerStatePoweredOn[\s\S]*startPendingConnectTimeoutIfNeeded/);
});

test("existing retry behavior is guarded against cancellation and duplicate callbacks", () => {
  const method = getMethod(
    "- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:"
  );

  assert.match(method, /shouldRetryConnectForError/);
  assert.match(method, /maxConnectRetries/);
  assert.match(method, /RNBluetoothPendingConnectPhaseRetryScheduled/);
  assert.match(method, /pendingConnectAddress[\s\S]*dispatch_after/);
  assert.match(method, /resumePendingConnectionIfPossible/);
});
