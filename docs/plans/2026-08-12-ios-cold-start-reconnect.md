# iOS Cold-Start Printer Reconnect Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make `BluetoothManager.connect(address)` wait for CoreBluetooth readiness on iOS, retrieve a saved peripheral by UUID before scanning, and settle exactly one Promise after writable-characteristic warmup.

**Architecture:** Keep one native pending-connect request with an explicit phase, one address, and one Promise owner. The exported React method and `centralManagerDidUpdateState` both delegate to `resumePendingConnectionIfPossible`; that helper gates work on `CBCentralManager.state`, safely hands off an existing peripheral, retrieves by `NSUUID`, and scans only as a fallback. Existing CoreBluetooth callbacks advance the phase through connection and writable discovery, while centralized resolve/reject cleanup prevents duplicate work or settlement.

**Tech Stack:** Objective-C, React Native bridge Promise blocks, CoreBluetooth, Node.js built-in test runner.

---

### Task 1: Lock down the cold-start lifecycle contract

**Files:**
- Create: `test/ios-cold-start-connect.test.js`
- Inspect: `ios/RNBluetoothManager.m`
- Inspect: `ios/RNBluetoothManager.h`

**Step 1: Write failing source-contract tests**

Cover transitional CoreBluetooth states, resume from `centralManagerDidUpdateState`, UUID retrieval before scan fallback, retrieved-peripheral connection, terminal-state rejection, cancellation through `disconnect`, duplicate-start/settlement guards, discovery callback gating, `callStop` isolation, bounded failure, and writable-ready resolution.

**Step 2: Run the focused test to verify RED**

Run: `node --test test/ios-cold-start-connect.test.js`

Expected: FAIL because the pending-connect helper, phase guards, retrieval-first path, terminal-state handling, and bounded timeout do not exist.

### Task 2: Implement the native pending-connect state machine

**Files:**
- Modify: `ios/RNBluetoothManager.m`

**Step 1: Add explicit pending phases and centralized cleanup**

Represent idle, waiting-for-Bluetooth, waiting-for-previous-disconnect, scanning, connecting, retry-scheduled, and writable-warmup phases. Keep timeout and pending peripheral state separate from discovery Promise state.

**Step 2: Add `resumePendingConnectionIfPossible`**

Treat `.unknown` and `.resetting` as transitional. Reject `.poweredOff`, `.unauthorized`, and `.unsupported`. When powered on, avoid duplicate work, hand off a different connected peripheral, attempt `retrievePeripheralsWithIdentifiers:`, reuse `foundDevices` if needed, and scan only when no peripheral is available.

**Step 3: Route the exported method and state callback through the helper**

Make `connect(address)` establish Promise ownership before resuming. Make `centralManagerDidUpdateState` resume the same request without recursively invoking the exported bridge method.

**Step 4: Gate callbacks by pending phase**

Allow only the matching discovery callback to start `connectPeripheral`; allow only the matching connection callback to begin writable discovery; guard retries and their delayed blocks; resume after the previous singleton peripheral disconnects.

**Step 5: Centralize settlement**

Clear address, phase, timeout, warmup state, waiting address, peripheral, and Promise properties exactly once before calling the captured resolve/reject block. Preserve connected/unable/lost events and writable-characteristic readiness.

**Step 6: Add a native timeout for active attempts**

Start the bounded timeout only after CoreBluetooth becomes powered on. On timeout, stop a pending fallback scan or cancel the pending peripheral connection, then reject with `CONNECT_TIMEOUT`.

### Task 3: Verify and publish

**Files:**
- Verify: `ios/RNBluetoothManager.m`
- Verify: `test/ios-cold-start-connect.test.js`

**Step 1: Run focused and full tests**

Run: `node --test test/ios-cold-start-connect.test.js`

Run: `npm test`

Expected: PASS with no failures.

**Step 2: Run repository checks**

Run: `git diff --check`

Expected: no output and exit code 0.

**Step 3: Run available iOS validation**

Inspect Xcode schemes and run the narrowest compile/test command supported by the standalone checkout. If React Native headers or an SDK destination are unavailable, report the exact environmental blocker.

**Step 4: Review state-machine invariants**

Compare the diff against every required lifecycle callback, Promise ownership rule, event contract, scan/cancel/disconnect behavior, retry behavior, and Android restriction.

**Step 5: Commit, push, and open a fork PR**

Stage only the plan, iOS implementation, and focused test. Push `agent/ios-cold-start-reconnect` to `ReneMercado/react-native-bluetooth-nest-printer` and create a draft PR targeting the fork's default branch.
