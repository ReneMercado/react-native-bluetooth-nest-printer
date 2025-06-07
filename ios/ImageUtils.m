//
//  ImageUtils.m
//  RNBluetoothEscposPrinter
//
//  Created by januslo on 2018/10/7.
//  Copyright © 2018年 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "ImageUtils.h"
#import <CoreGraphics/CoreGraphics.h>

@implementation ImageUtils : NSObject
int p0[] = { 0, 0x80 };
int p1[] = { 0, 0x40 };
int p2[] = { 0, 0x20 };
int p3[] = { 0, 0x10 };
int p4[] = { 0, 0x08 };
int p5[] = { 0, 0x04 };
int p6[] = { 0, 0x02 };

+ (UIImage*)imagePadLeft:(NSInteger) left withSource: (UIImage*)source
{
    CGSize orgSize = [source size];
    CGSize size = CGSizeMake(orgSize.width + [[NSNumber numberWithInteger: left] floatValue], orgSize.height);
    UIGraphicsBeginImageContext(size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context,
                                   [[UIColor whiteColor] CGColor]);
    CGContextFillRect(context, CGRectMake(0, 0, size.width, size.height));
    [source drawInRect:CGRectMake(left, 0, orgSize.width, orgSize.height)
             blendMode:kCGBlendModeNormal alpha:1.0];
    UIImage *paddedImage =  UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return paddedImage;
}


+ (uint8_t *)imageToGreyImage:(UIImage *)image {
  NSLog(@"[ImageUtils] → imageToGreyImage: image=%@ size=%.0fx%.0f scale=%.1f",
        image, image.size.width, image.size.height, image.scale);

  CGImageRef cgImage = image.CGImage;
  NSLog(@"[ImageUtils]    cgImage = %p", cgImage);
  if (!cgImage) {
    NSLog(@"[ImageUtils]    ❌ cgImage es NULL");
    return NULL;
  }

  size_t width  = CGImageGetWidth(cgImage);
  size_t height = CGImageGetHeight(cgImage);
  NSLog(@"[ImageUtils]    dimensions = %zux%zu", width, height);

  size_t dataSize = width * height;
  uint8_t *greyData = malloc(dataSize);
  NSLog(@"[ImageUtils]    malloc greyData = %p (%zu bytes)", greyData, dataSize);
  if (!greyData) {
    NSLog(@"[ImageUtils]    ❌ malloc falló");
    return NULL;
  }
  memset(greyData, 0, dataSize);

  CGColorSpaceRef graySpace =
    CGColorSpaceCreateDeviceGray();
  CGContextRef ctx = CGBitmapContextCreate(
    greyData,
    width,
    height,
    8,
    width,
    graySpace,
    kCGImageAlphaNone
  );
  CGColorSpaceRelease(graySpace);
  NSLog(@"[ImageUtils]    CGContext = %p", ctx);
  if (!ctx) {
    NSLog(@"[ImageUtils]    ❌ CGContextCreation falló");
    free(greyData);
    return NULL;
  }

  CGContextDrawImage(ctx, CGRectMake(0,0,width,height), cgImage);
  CGContextRelease(ctx);
  NSLog(@"[ImageUtils]    ✅ dibujado en contexto");

  return greyData;
}

+ (UIImage *)imageWithImage:(UIImage *)image scaledToFillSize:(CGSize)size
{
    CGFloat scale = MAX(size.width/image.size.width, size.height/image.size.height);
    CGFloat width = image.size.width * scale;
    CGFloat height = image.size.height * scale;
    CGRect imageRect = CGRectMake((size.width - width)/2.0f,
                                  (size.height - height)/2.0f,
                                  width,
                                  height);
    
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    [image drawInRect:imageRect];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

+ (NSData*)bitmapToArray:(UIImage*) bmp
{
    CGDataProviderRef provider = CGImageGetDataProvider(bmp.CGImage);
    NSData* data = (id)CFBridgingRelease(CGDataProviderCopyData(provider));
    return data;
}

/**
 **Raster Image - $1D $76 $30 m xL xH yL yH d1...dk
 Prints a raster image
 
 Format:
 Hex       $1D  $76 30  m xL xH yL yH d1...dk
 
 ASCII     GS   v   %   m xL xH yL yH d1...dk
 
 Decimal   29  118  48  m xL xH yL yH d1...dk
 
 Notes:
 When ​standard mode​ is enabled, this command is only executed when there is no data in the print buffer. (Line is empty)
 The defined data (​d​) defines each byte of the raster image. Each bit in every byte defines a pixel. A bit set to 1 is printed and a bit set to 0 is not printed.
 If a raster bit image exceeds one line, the excess data is not printed.
 This command feeds as much paper as is required to print the entire raster bit image, regardless of line spacing defined by 1/6" or 1/8" commands.
 After the raster bit image is printed, the print position goes to the beginning of the line.
 The following commands have no effect on a raster bit image:
 Emphasized
 Double Strike
 Underline
 White/Black Inverse Printing
 Upside-Down Printing
 Rotation
 Left margin
 Print Area Width
 A raster bit image data is printed in the following order:
 d1    d2    …    dx
 dx + 1    dx + 2    …    dx * 2
 .    .    .    .
 …    dk - 2    dk - 1    dk
 Defines and prints a raster bit image using the mode specified by ​m​:
 m    Mode    Width Scalar    Heigh Scalar
 0, 48    Normal    x1    x1
 1, 49    Double Width    x2    x1
 2, 50    Double Height    x1    x2
 3, 51    Double Width/Height    x2    x2
 xL, xH ​defines the raster bit image in the horizontal direction in ​bytes​ using two-byte number definitions. (​xL + (xH * 256)) Bytes
 yL, yH ​defines the raster bit image in the vertical direction in ​dots​ using two-byte number definitions. (​yL + (yH * 256)) Dots
 d ​ specifies the bit image data in raster format.
 k ​indicates the number of bytes in the bit image. ​k ​is not transmitted and is there for explanation only.
 **/
+ (NSData *)eachLinePixToCmd:(unsigned char *)src nWidth:(NSInteger) nWidth nHeight:(NSInteger) nHeight nMode:(NSInteger) nMode leftPadding:(NSInteger) leftPadding
{
    NSLog(@"SIZE OF SRC: %lu",sizeof(&src));
    NSInteger nBytesPerLine = (int)nWidth/8;
    NSInteger bytesPerLineWithPadding = nBytesPerLine;
    
    // Calculate padding bytes (each byte is 8 pixels)
    NSInteger paddingBytes = leftPadding / 8;
    if (leftPadding > 0) {
        bytesPerLineWithPadding += paddingBytes;
    }
    
    unsigned char * data = malloc(nHeight*(8+bytesPerLineWithPadding));
    NSInteger k = 0;
    
    for(int i=0; i<nHeight; i++){
        NSInteger var10 = i*(8+bytesPerLineWithPadding);
        //GS v 0 m xL xH yL yH d1....dk 打印光栅位图
        data[var10 + 0] = 29;//GS
        data[var10 + 1] = 118;//v
        data[var10 + 2] = 48;//0
        data[var10 + 3] = (unsigned char)(nMode & 1);
        data[var10 + 4] = (unsigned char)(bytesPerLineWithPadding % 256);//xL
        data[var10 + 5] = (unsigned char)(bytesPerLineWithPadding / 256);//xH
        data[var10 + 6] = 1;//yL
        data[var10 + 7] = 0;//yH
        
        // Add padding bytes (zeros = white space)
        for (int p = 0; p < paddingBytes; p++) {
            data[var10 + 8 + p] = 0;
        }
        
        // Add actual image data after padding
        for (int j = 0; j < nBytesPerLine; ++j) {
            data[var10 + 8 + paddingBytes + j] = (int)(p0[src[k]] + p1[src[k + 1]] + p2[src[k + 2]] + p3[src[k + 3]] + p4[src[k + 4]] + p5[src[k + 5]] + p6[src[k + 6]] + src[k + 7]);
            k = k + 8;
        }
    }
    
    return [NSData dataWithBytes:data length:nHeight*(8+bytesPerLineWithPadding)];
}

+ (NSData *)eachLinePixToCmd:(unsigned char *)src nWidth:(NSInteger) nWidth nHeight:(NSInteger) nHeight nMode:(NSInteger) nMode
{
    // Forward to new method with leftPadding=0
    return [self eachLinePixToCmd:src nWidth:nWidth nHeight:nHeight nMode:nMode leftPadding:0];
}

+(unsigned char *)format_K_threshold:(unsigned char *) orgpixels
                        width:(NSInteger) xsize height:(NSInteger) ysize
{
    NSLog(@"[ImageUtils] → format_K_threshold: size=%ldx%ld", (long)xsize, (long)ysize);
    
    unsigned char * despixels = malloc(xsize*ysize);
    int graytotal = 0;
    int k = 0;
    int minGray = 255, maxGray = 0;
    
    int i;
    int j;
    int gray;
    
    // First pass: calculate statistics
    for(i = 0; i < ysize; ++i) {
        for(j = 0; j < xsize; ++j) {
            gray = orgpixels[k] & 255;
            graytotal += gray;
            if(gray < minGray) minGray = gray;
            if(gray > maxGray) maxGray = gray;
            ++k;
        }
    }
    
    int grayave = graytotal / ysize / xsize;
    
    // Use improved threshold: midpoint between average and minimum for better contrast
    // This helps with logos that have dark content on light backgrounds
    int threshold = (grayave + minGray) / 2;
    
    // Ensure minimum contrast
    if(maxGray - minGray < 50) {
        threshold = grayave; // Fall back to average if low contrast
    }
    
    NSLog(@"[ImageUtils] Gray stats - Min:%d, Max:%d, Avg:%d, Threshold:%d", 
          minGray, maxGray, grayave, threshold);
    
    k = 0;
    int blackPixels = 0, whitePixels = 0;
    
    // Second pass: apply threshold
    for(i = 0; i < ysize; ++i) {
        for(j = 0; j < xsize; ++j) {
            gray = orgpixels[k] & 255;
            if(gray > threshold) {
                despixels[k] = 0; // White pixel (don't print)
                whitePixels++;
            } else {
                despixels[k] = 1; // Black pixel (print)
                blackPixels++;
            }
            ++k;
        }
    }
    
    NSLog(@"[ImageUtils] Threshold result - Black pixels: %d, White pixels: %d (%.1f%% black)", 
          blackPixels, whitePixels, (blackPixels * 100.0) / (blackPixels + whitePixels));
    
    return despixels;
}
+(NSData *)pixToTscCmd:(uint8_t *)src width:(NSInteger) width
{
    int length = (int)width/8;
    uint8_t * data = malloc(length);
    int k = 0;
    for(int j = 0;k<length;++k){
        data[k] =(uint8_t)(p0[src[j]] + p1[src[j + 1]] + p2[src[j + 2]] + p3[src[j + 3]] + p4[src[j + 4]] + p5[src[j + 5]] + p6[src[j + 6]] + src[j + 7]);
        j+=8;
    }
    return [[NSData alloc] initWithBytes:data length:length];
}

+(NSInteger)defaultWidth {
    // Return a default width (58mm printer width in pixels)
    return 384; // Standard 58mm printer width
}

@end
