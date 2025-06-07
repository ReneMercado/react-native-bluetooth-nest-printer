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
{
    NSLog(@"[PrintImageDelegate] didWriteDataToBle called - Success: %@, CurrentPosition: %ld, TotalLength: %ld", 
          success ? @"YES" : @"NO", (long)_now, (long)[_toPrint length]);
    
    if(success){
        if(_now == -1){
            NSLog(@"[PrintImageDelegate] Print operation already completed, resolving promise");
            if(_pendingResolve) {
                _pendingResolve(nil); 
                _pendingResolve=nil;
            }
        }else if(_now>=[_toPrint length]){
            NSLog(@"[PrintImageDelegate] All data sent successfully, sending printer reset command");
            // ASCII ESC M 0 CR LF - Reset printer after image
            // Hex 1B 4D 0 0D 0A
            // Decimal 27 77 0 13 10
            unsigned char * initPrinter = malloc(5);
            initPrinter[0]=27;
            initPrinter[1]=77;
            initPrinter[2]=0;
            initPrinter[3]=13;
            initPrinter[4]=10;
            
            @try {
                [RNBluetoothManager writeValue:[NSData dataWithBytes:initPrinter length:5] withDelegate:self];
                _now = -1;
                NSLog(@"[PrintImageDelegate] Printer reset command sent successfully");
                [NSThread sleepForTimeInterval:0.02f]; // Slight delay after reset
            } @catch (NSException *exception) {
                NSLog(@"[PrintImageDelegate] ERROR sending printer reset command: %@", exception.reason);
                free(initPrinter);
                if(_pendingReject) {
                    _pendingReject(@"PRINTER_RESET_FAILED", 
                                 [NSString stringWithFormat:@"Failed to send printer reset command: %@", exception.reason], 
                                 nil);
                    _pendingReject = nil;
                }
                return;
            }
            free(initPrinter);
        }else {
            NSLog(@"[PrintImageDelegate] More data to send, continuing print process");
            [self print];
        }
    }else {
        NSString *errorMsg = [NSString stringWithFormat:@"Failed to write data to printer at position %ld of %ld bytes", 
                             (long)_now, (long)[_toPrint length]];
        NSLog(@"[PrintImageDelegate] ERROR: %@", errorMsg);
        
        if(_pendingReject){
            _pendingReject(@"PRINT_IMAGE_FAILED", errorMsg, nil);
            _pendingReject = nil;
        }
    }
}

-(void) print
{
    @synchronized (self) {
        NSLog(@"[PrintImageDelegate] Starting print method - CurrentPosition: %ld, Width: %ld", (long)_now, (long)_width);
        
        // Calculate bytes per line based on width
        NSInteger sizePerLine = (int)(_width/8);
        NSLog(@"[PrintImageDelegate] Calculated sizePerLine: %ld (width: %ld)", (long)sizePerLine, (long)_width);
        
        // Enhanced safety checks
        if (!_toPrint || [_toPrint length] == 0) {
            NSString *errorMsg = @"No image data available to print";
            NSLog(@"[PrintImageDelegate] ERROR: %@", errorMsg);
            if(_pendingReject) {
                _pendingReject(@"NO_DATA_TO_PRINT", errorMsg, nil);
                _pendingReject = nil;
            }
            return;
        }
        
        if (_now < 0) {
            NSString *warningMsg = [NSString stringWithFormat:@"Invalid _now value: %ld, resetting to 0", (long)_now];
            NSLog(@"[PrintImageDelegate] WARNING: %@", warningMsg);
            _now = 0;
        }
        
        // Check if we've finished printing
        if (_now >= [_toPrint length]) {
            NSString *successMsg = [NSString stringWithFormat:@"Print completed successfully - total bytes processed: %ld", (long)[_toPrint length]];
            NSLog(@"[PrintImageDelegate] SUCCESS: %@", successMsg);
            _now = -1; // Mark as completed
            if(_pendingResolve) {
                _pendingResolve(nil);
                _pendingResolve = nil;
            }
            return;
        }
        
        // Calculate remaining bytes safely
        NSInteger remainingBytes = [_toPrint length] - _now;
        NSInteger actualSizeToRead = MIN(sizePerLine, remainingBytes);
        
        NSLog(@"[PrintImageDelegate] Data calculation - Remaining: %ld, SizePerLine: %ld, ActualToRead: %ld", 
              (long)remainingBytes, (long)sizePerLine, (long)actualSizeToRead);
        
        // Final safety check
        if (actualSizeToRead <= 0) {
            NSString *errorMsg = [NSString stringWithFormat:@"Invalid size to read: %ld (remaining: %ld, sizePerLine: %ld)", 
                                 (long)actualSizeToRead, (long)remainingBytes, (long)sizePerLine];
            NSLog(@"[PrintImageDelegate] ERROR: %@", errorMsg);
            
            // Try to complete the operation gracefully
            _now = -1;
            if(_pendingResolve) {
                _pendingResolve(nil);
                _pendingResolve = nil;
            }
            return;
        }
        
        // Create subdata safely
        @try {
            NSData *subData = [_toPrint subdataWithRange:NSMakeRange(_now, actualSizeToRead)];
            NSLog(@"[PrintImageDelegate] Sending data chunk - Size: %ld, Offset: %ld, Total: %ld, Progress: %.1f%%", 
                  (long)actualSizeToRead, (long)_now, (long)[_toPrint length], 
                  ((float)_now / (float)[_toPrint length]) * 100.0);
            
            [RNBluetoothManager writeValue:subData withDelegate:self];
            _now += actualSizeToRead;
            
            // Log the data being sent for debugging (first few bytes)
            if (subData.length > 0) {
                const unsigned char* bytes = (const unsigned char*)[subData bytes];
                NSMutableString *hexString = [NSMutableString string];
                NSInteger logLength = MIN(8, subData.length); // Log first 8 bytes
                for (NSInteger i = 0; i < logLength; i++) {
                    [hexString appendFormat:@"%02X ", bytes[i]];
                }
                NSLog(@"[PrintImageDelegate] Data preview (hex): %@%@", hexString, subData.length > 8 ? @"..." : @"");
            }
            
            // Slower timing for iOS stability
            [NSThread sleepForTimeInterval:0.1f];  // 100ms delay
            
        } @catch (NSException *exception) {
            NSString *errorMsg = [NSString stringWithFormat:@"Exception during data preparation: %@ - Reason: %@ - Stack: %@", 
                                 exception.name, exception.reason, [exception callStackSymbols]];
            NSLog(@"[PrintImageDelegate] EXCEPTION: %@", errorMsg);
            
            if(_pendingReject) {
                _pendingReject(@"DATA_PREPARATION_ERROR", errorMsg, nil);
                _pendingReject = nil;
            }
        }
    }
}

-(void)didReceiveData:(NSData *)data {
    const unsigned char* bytes = (const unsigned char*)[data bytes];
    NSMutableString *hexString = [NSMutableString string];
    for (NSInteger i = 0; i < MIN(data.length, 16); i++) { // Log first 16 bytes
        [hexString appendFormat:@"%02X ", bytes[i]];
    }
    
    NSLog(@"[PrintImageDelegate] Received data from printer - Length: %ld, Data: %@%@", 
          (long)data.length, hexString, data.length > 16 ? @"..." : @"");
    
    @synchronized(self) {
        // Check if we should continue or finish
        if (_now >= [_toPrint length] || _now < 0) {
            NSString *msg = [NSString stringWithFormat:@"Print operation completed or invalid state (now: %ld, total: %ld) - finishing", 
                           (long)_now, (long)[_toPrint length]];
            NSLog(@"[PrintImageDelegate] %@", msg);
            _now = -1; // Mark as completed
            if(_pendingResolve) {
                _pendingResolve(nil);
                _pendingResolve = nil;
            }
            return;
        }
        
        NSLog(@"[PrintImageDelegate] Scheduling next data chunk after 50ms delay");
        // Add a small delay before sending next chunk
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self print];
        });
    }
}

-(void)didFailToWriteData:(NSData*)data withError:(NSError*)error {
    NSString *errorMsg = [NSString stringWithFormat:@"Failed to write data to printer - Error Code: %ld, Description: %@, Data Length: %ld", 
                         (long)error.code, error.localizedDescription, (long)data.length];
    NSLog(@"[PrintImageDelegate] ERROR: %@", errorMsg);
    
    // Log additional error details
    if (error.userInfo) {
        NSLog(@"[PrintImageDelegate] Error UserInfo: %@", error.userInfo);
    }
    
    @synchronized(self) {
        if(_pendingReject) {
            _pendingReject(@"WRITE_DATA_FAILED", errorMsg, error);
            _pendingReject = nil;
        }
        _now = -1; // Reset state
    }
}
@end
