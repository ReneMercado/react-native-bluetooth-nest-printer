# Reliable Paired-Device Retrieval Design

## Goal

Expose Android's already bonded Bluetooth devices immediately through
`BluetoothManager.getPairedDevices()` without starting or waiting for Bluetooth
discovery.

## Considered approaches

1. **Add only a new native method with its own serialization loop.** This is the
   smallest diff, but it would create a third paired-device representation next
   to `enableBluetooth()` and `scanDevices()` and make future fixes easy to apply
   inconsistently.
2. **Change every paired-device API to return native maps.** This would give the
   cleanest API, but it would break consumers that parse the JSON strings
   returned by `enableBluetooth()` or the JSON result returned by
   `scanDevices()`.
3. **Use one native-map serializer and adapt only the legacy APIs.** This keeps
   the new method idiomatic while preserving the exact legacy result shapes.

Approach 3 is selected because it adds the reliable API without changing
existing consumer contracts.

## Native API and data flow

`getPairedDevices(Promise)` obtains the adapter through the existing
`getBluetoothAdapter()` helper. It rejects with
`EVENT_BLUETOOTH_NOT_SUPPORT` when no adapter exists and with the existing-style
`BT NOT ENABLED` error when Bluetooth is off. With an enabled adapter, it reads
`getBondedDevices()` once, converts the set to a React Native `WritableArray` of
`WritableMap` values, and resolves immediately. A missing device name is emitted
as `null`; every item includes its address.

The serializer is also used by `enableBluetooth()` and `scanDevices()`. Small
adapters convert its native maps back to those methods' legacy JSON-string and
`JSONArray` formats so their public behavior and events remain unchanged.
Neither the new method nor its serializer starts discovery, changes bond state,
or requests permissions.

## Errors and platform behavior

Android 12 and newer can throw `SecurityException` when the consuming app has
not granted `BLUETOOTH_CONNECT`. The new method catches that exception and
rejects with a stable `BLUETOOTH_CONNECT_PERMISSION_REQUIRED` code and a clear
message. The Android manifest declares `BLUETOOTH_CONNECT`, but the consuming
app remains responsible for runtime permission requests.

iOS has no Android-style bonded-device list, so no native iOS implementation is
added. The README and optional TypeScript method declaration identify the API as
Android-only instead of pretending there is a cross-platform equivalent.

## Validation

A Node contract test will assert the native method's immediate bonded-device
path, permission handling, manifest declaration, TypeScript signature, and
Android-only documentation while protecting `scanDevices()` discovery behavior.
Android compilation will be attempted with the repository's available build
tooling. Physical-device validation remains necessary for actual adapter and
permission behavior.
