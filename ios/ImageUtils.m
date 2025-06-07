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
    NSLog(@"[ImageUtils] → imagePadLeft: padding=%ld, source size=%.0fx%.0f", 
          (long)left, source.size.width, source.size.height);
    
    CGSize orgSize = [source size];
    CGSize size = CGSizeMake(orgSize.width + [[NSNumber numberWithInteger: left] floatValue], orgSize.height);
    
    NSLog(@"[ImageUtils]    new size will be: %.0fx%.0f", size.width, size.height);
    
    UIGraphicsBeginImageContext(size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context,
                                   [[UIColor whiteColor] CGColor]);
    CGContextFillRect(context, CGRectMake(0, 0, size.width, size.height));
    [source drawInRect:CGRectMake(left, 0, orgSize.width, orgSize.height)
             blendMode:kCGBlendModeNormal alpha:1.0];
    UIImage *paddedImage =  UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    if (paddedImage) {
        NSLog(@"[ImageUtils]    ✅ padding successful, final size: %.0fx%.0f", 
              paddedImage.size.width, paddedImage.size.height);
    } else {
        NSLog(@"[ImageUtils]    ❌ padding failed");
    }
    
    return paddedImage;
}


+ (uint8_t *)imageToGreyImage:(UIImage *)image {
  NSLog(@"[ImageUtils] → imageToGreyImage: ENTRY - image=%@ size=%.0fx%.0f scale=%.1f",
        image, image.size.width, image.size.height, image.scale);

  if (!image) {
    NSLog(@"[ImageUtils]    ❌ image parameter is NULL");
    return NULL;
  }

  CGImageRef cgImage = image.CGImage;
  NSLog(@"[ImageUtils]    cgImage = %p", cgImage);
  if (!cgImage) {
    NSLog(@"[ImageUtils]    ❌ cgImage es NULL");
    return NULL;
  }

  size_t width  = CGImageGetWidth(cgImage);
  size_t height = CGImageGetHeight(cgImage);
  NSLog(@"[ImageUtils]    dimensions = %zux%zu", width, height);

  if (width == 0 || height == 0) {
    NSLog(@"[ImageUtils]    ❌ invalid dimensions");
    return NULL;
  }

  size_t dataSize = width * height;
  uint8_t *greyData = malloc(dataSize);
  NSLog(@"[ImageUtils]    malloc greyData = %p (%zu bytes)", greyData, dataSize);
  if (!greyData) {
    NSLog(@"[ImageUtils]    ❌ malloc falló");
    return NULL;
  }
  memset(greyData, 0, dataSize);

  NSLog(@"[ImageUtils]    creating color space and context...");
  CGColorSpaceRef graySpace = CGColorSpaceCreateDeviceGray();
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

  NSLog(@"[ImageUtils]    drawing image into context...");
  CGContextDrawImage(ctx, CGRectMake(0,0,width,height), cgImage);
  CGContextRelease(ctx);
  NSLog(@"[ImageUtils]    ✅ successfully converted to grayscale (%zu bytes)", dataSize);

  return greyData;
}

+ (UIImage *)imageWithImage:(UIImage *)image scaledToFillSize:(CGSize)size
{
    NSLog(@"[ImageUtils] → imageWithImage:scaledToFillSize: source=%.0fx%.0f, target=%.0fx%.0f", 
          image.size.width, image.size.height, size.width, size.height);
    
    if (!image) {
        NSLog(@"[ImageUtils]    ❌ source image is NULL");
        return nil;
    }
    
    if (size.width <= 0 || size.height <= 0) {
        NSLog(@"[ImageUtils]    ❌ invalid target size");
        return nil;
    }
    
    CGFloat scale = MAX(size.width/image.size.width, size.height/image.size.height);
    CGFloat width = image.size.width * scale;
    CGFloat height = image.size.height * scale;
    CGRect imageRect = CGRectMake((size.width - width)/2.0f,
                                  (size.height - height)/2.0f,
                                  width,
                                  height);
    
    NSLog(@"[ImageUtils]    scale=%.3f, scaled size=%.0fx%.0f, rect=(%.0f,%.0f,%.0fx%.0f)", 
          scale, width, height, imageRect.origin.x, imageRect.origin.y, imageRect.size.width, imageRect.size.height);
    
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    [image drawInRect:imageRect];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    if (newImage) {
        NSLog(@"[ImageUtils]    ✅ scaling successful, final size: %.0fx%.0f", 
              newImage.size.width, newImage.size.height);
    } else {
        NSLog(@"[ImageUtils]    ❌ scaling failed");
    }
    
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
    NSLog(@"[ImageUtils] → eachLinePixToCmd (with padding): width=%ld, height=%ld, mode=%ld, padding=%ld", 
          (long)nWidth, (long)nHeight, (long)nMode, (long)leftPadding);
    
    if (!src) {
        NSLog(@"[ImageUtils]    ❌ src data is NULL");
        return nil;
    }
    
    if (nWidth <= 0 || nHeight <= 0) {
        NSLog(@"[ImageUtils]    ❌ invalid dimensions");
        return nil;
    }
    
    NSInteger sizePerLine = (int)(nWidth/8);
    if(nWidth%8 > 0) {
        sizePerLine += 1;
    }
    
    NSLog(@"[ImageUtils]    calculated sizePerLine: %ld", (long)sizePerLine);
    
    NSInteger cmdSize = 8 + sizePerLine * nHeight;
    NSLog(@"[ImageUtils]    allocating command buffer: %ld bytes", (long)cmdSize);
    
    unsigned char *cmdBuffer = malloc(cmdSize);
    if (!cmdBuffer) {
        NSLog(@"[ImageUtils]    ❌ malloc failed for command buffer");
        return nil;
    }
    
    NSLog(@"[ImageUtils]    building command header...");
    
    // Build command header
    cmdBuffer[0] = 0x1D;  // GS
    cmdBuffer[1] = 0x76;  // v
    cmdBuffer[2] = 0x30;  // 0
    cmdBuffer[3] = (unsigned char)nMode;
    
    cmdBuffer[4] = (unsigned char)(sizePerLine & 0xFF);
    cmdBuffer[5] = (unsigned char)((sizePerLine >> 8) & 0xFF);
    cmdBuffer[6] = (unsigned char)(nHeight & 0xFF);
    cmdBuffer[7] = (unsigned char)((nHeight >> 8) & 0xFF);
    
    NSLog(@"[ImageUtils]    header: [%02X %02X %02X %02X %02X %02X %02X %02X]", 
          cmdBuffer[0], cmdBuffer[1], cmdBuffer[2], cmdBuffer[3], 
          cmdBuffer[4], cmdBuffer[5], cmdBuffer[6], cmdBuffer[7]);
    
    NSLog(@"[ImageUtils]    processing pixel data...");
    
    // Process pixel data
    int destIndex = 8;
    for (int i = 0; i < nHeight; i++) {
        for (int j = 0; j < sizePerLine; j++) {
            unsigned char byte = 0;
            for (int k = 0; k < 8; k++) {
                int pixelIndex = i * nWidth + j * 8 + k;
                if (j * 8 + k < nWidth && pixelIndex < nWidth * nHeight) {
                    if (src[pixelIndex] == 1) {  // Black pixel
                        byte |= (0x80 >> k);
                    }
                }
            }
            cmdBuffer[destIndex++] = byte;
        }
    }
    
    NSLog(@"[ImageUtils]    ✅ command generation successful, total size: %ld bytes", (long)cmdSize);
    
    // Show first few bytes of image data for debugging
    NSMutableString *hexPreview = [NSMutableString stringWithString:@""];
    int previewBytes = MIN(16, (int)cmdSize);
    for (int i = 0; i < previewBytes; i++) {
        [hexPreview appendFormat:@"%02X ", cmdBuffer[i]];
    }
    NSLog(@"[ImageUtils]    Command preview: %@...", hexPreview);
    
    NSData *result = [NSData dataWithBytes:cmdBuffer length:cmdSize];
    free(cmdBuffer);
    
    return result;
}

+ (NSData *)eachLinePixToCmd:(unsigned char *)src nWidth:(NSInteger) nWidth nHeight:(NSInteger) nHeight nMode:(NSInteger) nMode
{
    NSLog(@"[ImageUtils] → eachLinePixToCmd: ENTRY - width=%ld, height=%ld, mode=%ld", 
          (long)nWidth, (long)nHeight, (long)nMode);
    
    if (!src) {
        NSLog(@"[ImageUtils]    ❌ src data is NULL");
        return nil;
    }
    
    return [self eachLinePixToCmd:src nWidth:nWidth nHeight:nHeight nMode:nMode leftPadding:0];
}

+(unsigned char *)format_K_threshold:(unsigned char *) orgpixels
                        width:(NSInteger) xsize height:(NSInteger) ysize
{
    NSLog(@"[ImageUtils] → format_K_threshold: ENTRY - size=%ldx%ld", (long)xsize, (long)ysize);
    
    if (!orgpixels) {
        NSLog(@"[ImageUtils]    ❌ orgpixels is NULL");
        return NULL;
    }
    
    if (xsize <= 0 || ysize <= 0) {
        NSLog(@"[ImageUtils]    ❌ invalid dimensions");
        return NULL;
    }
    
    unsigned char * despixels = malloc(xsize*ysize);
    if (!despixels) {
        NSLog(@"[ImageUtils]    ❌ malloc failed for despixels");
        return NULL;
    }
    
    int graytotal = 0;
    int k = 0;
    int minGray = 255, maxGray = 0;
    
    int i;
    int j;
    int gray;
    
    NSLog(@"[ImageUtils]    calculating statistics...");
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
    
    int grayave = graytotal / (xsize * ysize);
    
    // Use improved threshold: midpoint between average and minimum for better contrast
    // This helps with logos that have dark content on light backgrounds
    int threshold = (grayave + minGray) / 2;
    
    NSLog(@"[ImageUtils]    Gray stats - Min:%d, Max:%d, Avg:%d, Threshold:%d", 
          minGray, maxGray, grayave, threshold);
    
    // Second pass: apply threshold
    k = 0;
    int blackPixels = 0, whitePixels = 0;
    NSLog(@"[ImageUtils]    applying threshold...");
    
    for(i = 0; i < ysize; ++i) {
        for(j = 0; j < xsize; ++j) {
            gray = orgpixels[k] & 255;
            if(gray > threshold) {
                despixels[k] = 0;  // White pixel
                whitePixels++;
            } else {
                despixels[k] = 1;  // Black pixel  
                blackPixels++;
            }
            ++k;
        }
    }
    
    float blackPercent = (float)blackPixels / (float)(xsize * ysize) * 100.0f;
    float whitePercent = (float)whitePixels / (float)(xsize * ysize) * 100.0f;
    
    NSLog(@"[ImageUtils]    ✅ Final result - Black pixels: %d (%.1f%%), White pixels: %d (%.1f%%)",
          blackPixels, blackPercent, whitePixels, whitePercent);
    
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
