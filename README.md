# react-native-bluetooth-nest-printer

[![version](https://img.shields.io/badge/version-1.0.5-4CAF50)](https://www.npmjs.com/package/react-native-bluetooth-nest-printer)
[![version](https://img.shields.io/badge/react--native-0.7x-1E88E5)](https://www.npmjs.com/package/react-native-bluetooth-nest-printer)

## Important Note on This Fork

This fork modifies the original package to use CocoaPods for managing the ZXingObjC dependency instead of bundling it with the package. This helps prevent conflicts when used with other packages that also use ZXingObjC (like expo-camera).

To use this modified version:

```bash
# Using npm
npm install --save ReneMercado/react-native-bluetooth-nest-printer

# Using yarn
yarn add github:ReneMercado/react-native-bluetooth-nest-printer
```

Then in your iOS project:

```bash
cd ios
pod install
```

---

This library is complete from [react-native-bluetooth-escpos-printer](https://github.com/januslo/react-native-bluetooth-escpos-printer), thanks Januslo!

React-Native plugin for the bluetooth ESC/POS & TSC printers

Any questions or bug please raise a [issue](https://github.com/chaudev/react-native-bluetooth-nest-printer/issues)

Worked for Android and IOS

For print text in Vietnamese, it is necessary to use a printer that supports Vietnamese

## Installation

### Step 1

Install via npm [Check In NPM](https://www.npmjs.com/package/react-native-bluetooth-nest-printer)

```bash
npm install react-native-bluetooth-nest-printer
```

Or yarn

```bash
yarn add react-native-bluetooth-nest-printer
```

### Step 2

- Android (on React Native 0.7x no need to do this step):

Link the plugin to your RN project

```bash
npx react-native link react-native-bluetooth-nest-printer
```

- IOS:

```bash
pod install
```

### Step 3

Refers to your JS files

```javascript
import {
  BluetoothManager,
  BluetoothEscposPrinter,
  BluetoothTscPrinter,
} from "react-native-bluetooth-nest-printer";
```

## Usage and APIs

### BluetoothManager

BluetoothManager is the module that for Bluetooth service management, supports Bluetooth status check, enable / disable Bluetooth service, scan devices, connect / unpaire devices.

- isBluetoothEnabled =>
  async function, check whether Bluetooth service is enabled

```javascript
BluetoothManager.isBluetoothEnabled().then(
  (enabled) => {
    alert(enabled); // enabled ==> true /false
  },
  (err) => {
    alert(err);
  }
);
```

- enableBluetooth ==> `diff + ANDROID ONLY`
  async function, enable the bluetooth service, returns the devices information already bound and paired. `diff - IOS would just resovle with nil`

```javascript
BluetoothManager.enableBluetooth().then(
  (r) => {
    var paired = [];
    if (r && r.length > 0) {
      for (var i = 0; i < r.length; i++) {
        try {
          paired.push(JSON.parse(r[i])); // NEED TO PARSE THE DEVICE INFORMATION
        } catch (e) {
          //ignore
        }
      }
    }
    console.log(JSON.stringify(paired));
  },
  (err) => {
    alert(err);
  }
);
```

- disableBluetooth ==> `diff + ANDROID ONLY`
  async function ,disable the bluetooth service. `diff - IOS would just resovle with nil`

```javascript
BluetoothManager.disableBluetooth().then(
  () => {
    // do something.
  },
  (err) => {
    alert(err);
  }
);
```

- scanDevices ==>
  async function , scans the bluetooth devices, returns devices found and pared after scan finish. Event [BluetoothManager.EVENT_DEVICE_ALREADY_PAIRED] would be emitted with devices bound; event [BluetoothManager.EVENT_DEVICE_FOUND] would be emitted (many time) as long as new devices found.

samples with events:

```javascript
DeviceEventEmitter.addListener(
  BluetoothManager.EVENT_DEVICE_ALREADY_PAIRED,
  (rsp) => {
    this._deviceAlreadPaired(rsp); // rsp.devices would returns the paired devices array in JSON string.
  }
);
DeviceEventEmitter.addListener(BluetoothManager.EVENT_DEVICE_FOUND, (rsp) => {
  this._deviceFoundEvent(rsp); // rsp.devices would returns the found device object in JSON string
});
```

samples with scanDevices function

```javascript
BluetoothManager.scanDevices().then(
  (s) => {
    var ss = JSON.parse(s); //JSON string
    this.setState(
      {
        pairedDs: this.state.pairedDs.cloneWithRows(ss.paired || []),
        foundDs: this.state.foundDs.cloneWithRows(ss.found || []),
        loading: false,
      },
      () => {
        this.paired = ss.paired || [];
        this.found = ss.found || [];
      }
    );
  },
  (er) => {
    this.setState({
      loading: false,
    });
    alert("error" + JSON.stringify(er));
  }
);
```

- connect ==>
  async function, connect the specified devices, if not bound, bound dailog promps.

```javascript
BluetoothManager.connect(rowData.address) // the device address scanned.
  .then(
    (s) => {
      this.setState({
        loading: false,
        boundAddress: rowData.address,
      });
    },
    (e) => {
      this.setState({
        loading: false,
      });
      alert(e);
    }
  );
```

- unpaire ==>
  async function, disconnect and unpaire the specified devices

```javascript
BluetoothManager.connect(rowData.address).then(
  (s) => {
    //success here
  },
  (err) => {
    //error here
  }
);
```

- Events of BluetoothManager module

| Name/KEY                    | DESCRIPTION                                            |
| --------------------------- | ------------------------------------------------------ |
| EVENT_DEVICE_ALREADY_PAIRED | Emits the devices array already paired                 |
| EVENT_DEVICE_DISCOVER_DONE  | Emits when the scan done                               |
| EVENT_DEVICE_FOUND          | Emits when device found during scan                    |
| EVENT_CONNECTION_LOST       | Emits when device connection lost                      |
| EVENT_UNABLE_CONNECT        | Emits when error occurs while trying to connect device |
| EVENT_CONNECTED             | Emits when device connected                            |
| EVENT_BLUETOOTH_NOT_SUPPORT | Emits when device not support bluetooth(android only)  |

### BluetoothTscPrinter

The printer for label printing.

- printLabel ==>
  async function the perform label print action.

```javascript
BluetoothTscPrinter.printLable(options).then(
  () => {
    //success
  },
  (err) => {
    //error
  }
);
```

#### Options of printLabel( ) function: (JSON object)

##### width

    label with , the real size of the label, matured by mm usualy.

##### height

    label height, the real size of the label, matured by mm usualy.

##### direction

    the printing direction, constants of BluetoothTscPrinter.DIRECTION, values BluetoothTscPrinter.DIRECTION.FORWARD/BluetoothTscPrinter.DIRECTION.BACKWARD (0/1)

##### gap

    the gap between 2 labels, matured by mm usualy.

##### reference

    the "zero" position of the label, values [x,y], default [0,0]

##### tear

    switch of the paper cut, constants of BluetoothTscPrinter.TEAR, values ON/OFF (string 'ON','OFF')

##### sound

    switch of the bee sound, values 0/1

##### text

    the collection of texts to print, contains following fields as the configuration:
        * text
            the text string,
        * x
            the text print start position-x
        * y
            the text print start position-y
        * fonttype
            the font type of the text, constanst of BluetoothTscPrinter.FONTTYPE,refereces as table:
                | CONSTANTS | VALUE   |
                |---|---|
                |FONT_1| "1"|
                |FONT_2| "2"|
                |FONT_3| "3"|
                |FONT_4| "4"|
                |FONT_5| "5"|
                |FONT_6| "6"|
                |FONT_7| "7"|
                |FONT_8|"8"|
                |SIMPLIFIED_CHINESE| "TSS24.BF2"|
                |TRADITIONAL_CHINESE| "TST24.BF2"|
                |KOREAN| "K"|
        * rotation
            the rotation of the text, constants of the BluetoothTscPrinter.ROTATION, referces as table:
                   | CONSTANTS | VALUE   |
                   |---|---|
                   |ROTATION_0| 0|
                   |ROTATION_90| 90|
                   |ROTATION_180| 180|
                   |ROTATION_270| 270|
        * xscal
            the scal in x,
        * yscal
            the scal in y, xscal/yscal is the constants of the BluetoothTscPrinter.FONTMUL, referces as table:
             | CONSTANTS | VALUE   |
             |---|---|
             |MUL_1| 1|
             |MUL_2| 2|
             |MUL_3| 3|
             |MUL_4| 4|
             |MUL_5| 5|
             |MUL_6| 6|
             |MUL_7| 7|
             |MUL_8| 8|
             |MUL_9| 9|
             |MUL_10: 10|

##### qrcode

    the collection of qrcodes to print, contains following fields as the configuration:
        * code
            the qrcode content string.
        * x
            the print start position at x
        * y
            the print start position at y
        * level
            the error correction level, constants of BluetoothTscPrinter.EEC, referces as tables:
            | CONSTANTS | VALUE   |
            |---|---|
            |LEVEL_L|"L"|
            |LEVEL_M| "M"|
            |LEVEL_Q| "Q"|
            |LEVEL_H| "H"|
        * width
            the qrcode size (width X width),since the qrcode are squre normally, so we just config the width.

        * rotation
            rationtion. the same as text object.

##### barcode

    the collection of barcode to print, contains foloowing fields as configuration
      * x
        the print start position of x,
      * y
        the print start position of y,
      * type
        the barcode type, constants of BluetoothTscPrinter, definition as table:
        | CONSTRANTS | VALUE |
        |---|---|
        | CODE128 | "128" |
        | CODE128M | "128M" |
        | EAN128 | "EAN128" |
        | ITF25 | "25" |
        | ITF25C | "25C" |
        | CODE39 | "39" |
        | CODE39C | "39C" |
        | CODE39S | "39S" |
        | CODE93 | "93" |
        | EAN13 | "EAN13" |
        | EAN13_2 | "EAN13+2" |
        | EAN13_5 | "EAN13+5" |
        | EAN8 | "EAN8" |
        | EAN8_2 | "EAN8+2" |
        | EAN8_5 | "EAN8+5" |
        | CODABAR | "CODA" |
        | POST | "POST" |
        | UPCA | "EAN13" |
        | UPCA_2 | "EAN13+2" |
        | UPCA_5 | "EAN13+5" |
        | UPCE | "EAN13" |
        | UPCE_2 | "EAN13+2" |
        | UPCE_5 | "EAN13+5" |
        | CPOST | "CPOST" |
        | MSI | "MSI" |
        | MSIC | "MSIC" |
        | PLESSEY | "PLESSEY" |
        | ITF14 | "ITF14" |
        | EAN14 | "EAN14" |

     * height
      the height of the barcode.
     * readable
      the hunman readable factor, 0-not readable, 1-readable.
     * rotation
      rotation, the same as text.
     * code
      the code to generate and print, should follow the restriction of the code type using.
     * wide
     the wide bar lines width (dot)
     * narrow
     the narrow bar line widht (dot)

##### image

    the collection of the image to print.
     * x
     the print start position x.
     * y
     the print start position y.
     * mode
     the bitmap mode of print, constants of BluetoothTscPrinter.BITMAP_MODE, valuse OVERWRITE(0),OR(1),XOR(2).
     * width
     the width of the image to print. (height will be calculated by image ratio)
     * image
     the base64 encoded image data(without schema)

#### demo of printLabel() options

```javascript
let options = {
  width: 40,
  height: 30,
  gap: 20,
  direction: BluetoothTscPrinter.DIRECTION.FORWARD,
  reference: [0, 0],
  tear: BluetoothTscPrinter.TEAR.ON,
  sound: 0,
  text: [
    {
      text: "I am a testing txt",
      x: 20,
      y: 0,
      fonttype: BluetoothTscPrinter.FONTTYPE.SIMPLIFIED_CHINESE,
      rotation: BluetoothTscPrinter.ROTATION.ROTATION_0,
      xscal: BluetoothTscPrinter.FONTMUL.MUL_1,
      yscal: BluetoothTscPrinter.FONTMUL.MUL_1,
    },
    {
      text: "你在说什么呢?",
      x: 20,
      y: 50,
      fonttype: BluetoothTscPrinter.FONTTYPE.SIMPLIFIED_CHINESE,
      rotation: BluetoothTscPrinter.ROTATION.ROTATION_0,
      xscal: BluetoothTscPrinter.FONTMUL.MUL_1,
      yscal: BluetoothTscPrinter.FONTMUL.MUL_1,
    },
  ],
  qrcode: [
    {
      x: 20,
      y: 96,
      level: BluetoothTscPrinter.EEC.LEVEL_L,
      width: 3,
      rotation: BluetoothTscPrinter.ROTATION.ROTATION_0,
      code: "show me the money",
    },
  ],
  barcode: [
    {
      x: 120,
      y: 96,
      type: BluetoothTscPrinter.BARCODETYPE.CODE128,
      height: 40,
      readable: 1,
      rotation: BluetoothTscPrinter.ROTATION.ROTATION_0,
      code: "1234567890",
    },
  ],
  image: [
    {
      x: 160,
      y: 160,
      mode: BluetoothTscPrinter.BITMAP_MODE.OVERWRITE,
      width: 60,
      image: base64Image,
    },
  ],
};
```

### BluetoothEscposPrinter

the printer for receipt printing, following ESC/POS command.

#### printerInit()

init the printer.

#### printAndFeed(int feed)

printer the buffer data and feed (feed lines).

#### printerLeftSpace(int sp)

set the printer left spaces.

#### printerLineSpace(int sp)

set the spaces between lines.

#### printerUnderLine(int line)

set the under line of the text, @param line -- 0-off,1-on,2-deeper

#### printerAlign(int align)

set the printer alignment, constansts: BluetoothEscposPrinter.ALIGN.LEFT/BluetoothEscposPrinter.ALIGN.CENTER/BluetoothEscposPrinter.ALIGN.RIGHT.
Not works ant printPic() method.

#### printText(String text, ReadableMap options)

print text, options as following:

- encoding => text encoding,default GBK.
- codepage => codepage using, default 0.
- widthtimes => text font mul times in width, default 0.
- heigthTimes => text font mul times in height, default 0.
- fonttype => text font type, default 0.

#### printColumn(ReadableArray columnWidths,ReadableArray columnAligns,ReadableArray columnTexts,ReadableMap options)

print texts in column, Parameters as following:

- columnWidths => int arrays, configs the width of each column, calculate by english character length. ex:the width of "abcdef" is 5 ,the width of "中文" is 4.
- columnAligns => arrays, alignment of each column, values is the same of printerAlign().
- columnTexts => arrays, the texts of each colunm to print.
- options => text print config options, the same of printText() options.

#### setWidth(int width)

sets the widht of the printer.

#### printPic(String base64encodeStr,ReadableMap options)

prints the image which encoded by base64, without schema.

- options: contains the params that may use in printing pic: "with":the pic with,basic on devices width(dots,58mm-384); "left":the left padding of the pic,for the printing position adjustment.

#### setfTest()

prints the selft test.

#### rotate()

set the rotate of the line.

#### setBlob(int weight)

set blob of the line.

#### printQRCode(String content, int size, int correctionLevel, int leftPadding)

prints the qrcode.

- `content`: String, the QR code content
- `size`: int, the QR code size (width X width)
- `correctionLevel`: int, error correction level, using `BluetoothEscposPrinter.ERROR_CORRECTION` constants
- `leftPadding`: int, optional padding from the left edge in pixels. If set to 0 or negative, the QR code will be automatically centered based on the printer's width.

Example usage:

```javascript
// Print QR code with auto-centering
await BluetoothEscposPrinter.printQRCode(
  "https://example.com", 
  200,  // size
  BluetoothEscposPrinter.ERROR_CORRECTION.M,  // error correction level
  0     // 0 for auto-center
);

// Print QR code with custom left padding
await BluetoothEscposPrinter.printQRCode(
  "https://example.com", 
  200,  // size
  BluetoothEscposPrinter.ERROR_CORRECTION.M,  // error correction level
  100   // 100 pixels from left edge
);
```

#### printBarCode(String str,int nType, int nWidthX, int nHeight, int nHriFontType, int nHriFontPosition)

prints the barcode.

### Demos of printing a receipt

```javascript
await BluetoothEscposPrinter.printerAlign(BluetoothEscposPrinter.ALIGN.CENTER);
await BluetoothEscposPrinter.setBlob(0);
await BluetoothEscposPrinter.printText("广州俊烨\n\r", {
  encoding: "GBK",
  codepage: 0,
  widthtimes: 3,
  heigthtimes: 3,
  fonttype: 1,
});
await BluetoothEscposPrinter.setBlob(0);
await BluetoothEscposPrinter.printText("销售单\n\r", {
  encoding: "GBK",
  codepage: 0,
  widthtimes: 0,
  heigthtimes: 0,
  fonttype: 1,
});
await BluetoothEscposPrinter.printerAlign(BluetoothEscposPrinter.ALIGN.LEFT);
await BluetoothEscposPrinter.printText("客户：零售客户\n\r", {});
await BluetoothEscposPrinter.printText("单号：xsd201909210000001\n\r", {});
await BluetoothEscposPrinter.printText(
  "日期：" + dateFormat(new Date(), "yyyy-mm-dd h:MM:ss") + "\n\r",
  {}
);
await BluetoothEscposPrinter.printText("销售员：18664896621\n\r", {});
await BluetoothEscposPrinter.printText(
  "--------------------------------\n\r",
  {}
);
let columnWidths = [12, 6, 6, 8];
await BluetoothEscposPrinter.printColumn(
  columnWidths,
  [
    BluetoothEscposPrinter.ALIGN.LEFT,
    BluetoothEscposPrinter.ALIGN.CENTER,
    BluetoothEscposPrinter.ALIGN.CENTER,
    BluetoothEscposPrinter.ALIGN.RIGHT,
  ],
  ["商品", "数量", "单价", "金额"],
  {}
);
await BluetoothEscposPrinter.printColumn(
  columnWidths,
  [
    BluetoothEscposPrinter.ALIGN.LEFT,
    BluetoothEscposPrinter.ALIGN.LEFT,
    BluetoothEscposPrinter.ALIGN.CENTER,
    BluetoothEscposPrinter.ALIGN.RIGHT,
  ],
  [
    "React-Native定制开发我是比较长的位置你稍微看看是不是这样?",
    "1",
    "32000",
    "32000",
  ],
  {}
);
await BluetoothEscposPrinter.printText("\n\r", {});
await BluetoothEscposPrinter.printColumn(
  columnWidths,
  [
    BluetoothEscposPrinter.ALIGN.LEFT,
    BluetoothEscposPrinter.ALIGN.LEFT,
    BluetoothEscposPrinter.ALIGN.CENTER,
    BluetoothEscposPrinter.ALIGN.RIGHT,
  ],
  [
    "React-Native定制开发我是比较长的位置你稍微看看是不是这样?",
    "1",
    "32000",
    "32000",
  ],
  {}
);
await BluetoothEscposPrinter.printText("\n\r", {});
await BluetoothEscposPrinter.printText(
  "--------------------------------\n\r",
  {}
);
await BluetoothEscposPrinter.printColumn(
  [12, 8, 12],
  [
    BluetoothEscposPrinter.ALIGN.LEFT,
    BluetoothEscposPrinter.ALIGN.LEFT,
    BluetoothEscposPrinter.ALIGN.RIGHT,
  ],
  ["合计", "2", "64000"],
  {}
);
await BluetoothEscposPrinter.printText("\n\r", {});
await BluetoothEscposPrinter.printText("折扣率：100%\n\r", {});
await BluetoothEscposPrinter.printText("折扣后应收：64000.00\n\r", {});
await BluetoothEscposPrinter.printText("会员卡支付：0.00\n\r", {});
await BluetoothEscposPrinter.printText("积分抵扣：0.00\n\r", {});
await BluetoothEscposPrinter.printText("支付金额：64000.00\n\r", {});
await BluetoothEscposPrinter.printText("结算账户：现金账户\n\r", {});
await BluetoothEscposPrinter.printText("备注：无\n\r", {});
await BluetoothEscposPrinter.printText("快递单号：无\n\r", {});
await BluetoothEscposPrinter.printText(
  "打印时间：" + dateFormat(new Date(), "yyyy-mm-dd h:MM:ss") + "\n\r",
  {}
);
await BluetoothEscposPrinter.printText(
  "--------------------------------\n\r",
  {}
);
await BluetoothEscposPrinter.printText("电话：\n\r", {});
await BluetoothEscposPrinter.printText("地址:\n\r\n\r", {});
await BluetoothEscposPrinter.printerAlign(BluetoothEscposPrinter.ALIGN.CENTER);
await BluetoothEscposPrinter.printText("欢迎下次光临\n\r\n\r\n\r", {});
await BluetoothEscposPrinter.printerAlign(BluetoothEscposPrinter.ALIGN.LEFT);
```

## Contact

- Website: https://ischau.org
- Website 2: https://dovuihainao.com
- Telegram: https://t.me/baochau9xx
- Facebook: https://facebook.com/baochau9xx
- Mail: chau.02it@gmail.com

## Keyword

- react-native-bluetooth-nest-printer, react-native, react-native-bluetooth, react-native-printer
- bluetooth-printer, react-native-bluetooth-printer
- baochau, baochau9xx, ischau, ischau.org
- dovuihainao
