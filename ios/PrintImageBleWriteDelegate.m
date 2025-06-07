//
//  PrintImageBleWriteDelegate.m
//  RNBluetoothEscposPrinter
//
//  Created by januslo on 2018/10/8.
//  Copyright © 2018年 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PrintImageBleWriteDelegate.h"
@implementation PrintImageBleWriteDelegate


- (void) didWriteDataToBle: (BOOL)success
{NSLog(@"PrintImageBleWriteDelete diWriteDataToBle: %d",success?1:0);
    if(success){
        if(_now == -1){
             if(_pendingResolve) {_pendingResolve(nil); _pendingResolve=nil;}
        }else if(_now>=[_toPrint length]){
//            ASCII ESC M 0 CR LF
//            Hex 1B 4D 0 0D 0A
//            Decimal 27 77 0 13 10
            unsigned char * initPrinter = malloc(5);
            initPrinter[0]=27;
            initPrinter[1]=77;
            initPrinter[2]=0;
            initPrinter[3]=13;
            initPrinter[4]=10;
            [RNBluetoothManager writeValue:[NSData dataWithBytes:initPrinter length:5] withDelegate:self];
            _now = -1;
            [NSThread sleepForTimeInterval:0.01f];
        }else {
            [self print];
        }
    }else if(_pendingReject){
        _pendingReject(@"PRINT_IMAGE_FAILED",@"PRINT_IMAGE_FAILED",nil);
        _pendingReject = nil;
    }
    
}

-(void) print
{
    @synchronized (self) {
        NSInteger sizePerLine = (int)(_width/8);
        
        // Add bounds checking to prevent crash
        if (_now >= [_toPrint length]) {
            NSLog(@"Print completed - no more data");
            return;
        }
        
        // Ensure we don't read beyond the data length
        NSInteger remainingBytes = [_toPrint length] - _now;
        if (sizePerLine > remainingBytes) {
            sizePerLine = remainingBytes;
        }
        
        // Additional safety check
        if (sizePerLine <= 0) {
            NSLog(@"Invalid sizePerLine: %ld", (long)sizePerLine);
            return;
        }
        
        NSData *subData = [_toPrint subdataWithRange:NSMakeRange(_now, sizePerLine)];
        NSLog(@"Write data: %@ (size: %ld, _now: %ld, total: %ld)", 
              subData, (long)sizePerLine, (long)_now, (long)[_toPrint length]);
        
        [RNBluetoothManager writeValue:subData withDelegate:self];
        _now = _now + sizePerLine;
        
        // Increase sleep time for iOS Bluetooth stability
        [NSThread sleepForTimeInterval:0.05f];  // Increased from 0.01f to 0.05f
    }
}
@end
