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
