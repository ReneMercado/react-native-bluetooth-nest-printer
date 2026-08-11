# Reliable Paired-Device Retrieval Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add an Android-only `BluetoothManager.getPairedDevices()` API that immediately returns bonded devices as native objects without starting discovery.

**Architecture:** Build one `WritableArray` serializer for bonded `BluetoothDevice` values. Resolve that array directly from the new method, while adapting it back to the legacy encoded result shapes used by `enableBluetooth()` and `scanDevices()`.

**Tech Stack:** Java/Android Bluetooth APIs, React Native native-module bridge, Node.js built-in test runner, TypeScript declarations, Markdown.

---

### Task 1: Add the paired-device API contract test

**Files:**
- Create: `test/paired-devices-api.test.js`
- Modify: `package.json`

**Step 1: Write the failing test**

Add Node tests that inspect the Android module, manifest, declarations, and
README. Assert that the new method reads bonded devices, rejects unsupported and
disabled Bluetooth, catches `SecurityException`, never starts discovery, has a
typed `Promise<BluetoothDevice[]>` signature, and is documented as Android-only.

**Step 2: Run test to verify it fails**

Run: `npm test`

Expected: FAIL because `getPairedDevices` and its public contract do not exist.

**Step 3: Commit the red test and design documents**

Run:

```bash
git add package.json test/paired-devices-api.test.js docs/plans
git commit -m "test paired device retrieval contract"
```

### Task 2: Implement the Android native method

**Files:**
- Modify: `android/src/main/java/cn/jystudio/bluetooth/RNBluetoothManagerModule.java`
- Modify: `android/src/main/AndroidManifest.xml`

**Step 1: Add one reusable serializer**

Create a helper that converts `Set<BluetoothDevice>` to a `WritableArray` of
maps with nullable `name` and required `address`. Add small legacy adapters for
the formats already returned by `enableBluetooth()` and `scanDevices()`.

**Step 2: Add `getPairedDevices`**

Obtain the existing adapter, reject unsupported and disabled states, resolve the
serializer output immediately, and catch `SecurityException` as
`BLUETOOTH_CONNECT_PERMISSION_REQUIRED`. Do not request permission or call
discovery.

**Step 3: Declare the Android permission**

Add `android.permission.BLUETOOTH_CONNECT` to the library manifest.

**Step 4: Run the focused test**

Run: `npm test`

Expected: Android assertions pass; type/documentation assertions still fail.

### Task 3: Add typings and documentation

**Files:**
- Modify: `index.d.ts`
- Modify: `README.md`

**Step 1: Add the public device type and method declaration**

Declare `{ name: string | null; address: string }` and an Android-only optional
`getPairedDevices(): Promise<BluetoothDevice[]>` method on the exported native
manager.

**Step 2: Add the README example**

Document that the API immediately reads Android bonded devices, does not run a
scan, requires the Android 12+ runtime permission, and has no iOS equivalent.

**Step 3: Run the focused test**

Run: `npm test`

Expected: PASS.

### Task 4: Validate and publish

**Files:**
- Review all changed files.

**Step 1: Run fresh validation**

Run `npm test`, a TypeScript declaration smoke check, and the available Android
library compilation command. Record any environment-only build limitation.

**Step 2: Inspect compatibility**

Review `git diff` and verify that existing `scanDevices()` events/result JSON,
`enableBluetooth()` encoded strings, and `startDiscovery()` behavior remain.

**Step 3: Request code review and address findings**

Review the final diff against the supplied acceptance criteria and fix all
critical or important findings.

**Step 4: Commit and publish**

Commit the implementation, push `codex/android-paired-devices`, and create a
ready-for-review PR against the repository's default branch with detailed test
and manual validation instructions.
