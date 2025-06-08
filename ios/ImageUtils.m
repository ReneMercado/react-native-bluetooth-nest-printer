//
//  ImageUtils.m
//  RNBluetoothEscposPrinter
//
//  Created by januslo on 2018/10/7.
//  Copyright © 2018年 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreImage/CoreImage.h>
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

  // ⭐ AGGRESSIVE DEBUG: Check original image properties
  CGColorSpaceRef originalColorSpace = CGImageGetColorSpace(cgImage);
  CGBitmapInfo originalBitmapInfo = CGImageGetBitmapInfo(cgImage);
  size_t originalBitsPerComponent = CGImageGetBitsPerComponent(cgImage);
  size_t originalBitsPerPixel = CGImageGetBitsPerPixel(cgImage);
  
  NSLog(@"[ImageUtils]    ORIGINAL IMAGE ANALYSIS:");
  NSLog(@"[ImageUtils]      BitsPerComponent: %zu", originalBitsPerComponent);
  NSLog(@"[ImageUtils]      BitsPerPixel: %zu", originalBitsPerPixel);
  NSLog(@"[ImageUtils]      BitmapInfo: %u", (unsigned int)originalBitmapInfo);
  NSLog(@"[ImageUtils]      HasAlpha: %s", (originalBitmapInfo & kCGBitmapAlphaInfoMask) != kCGImageAlphaNone ? "YES" : "NO");

  // ⭐ SIMPLE & DIRECT: Create white-background image with explicit RGB drawing
  NSLog(@"[ImageUtils]    SIMPLIFIED approach: creating RGB image with explicit WHITE background...");
  
  // Create RGB color space
  CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
  if (!rgbColorSpace) {
    NSLog(@"[ImageUtils]    ❌ Failed to create RGB color space");
    return NULL;
  }
  
  // Allocate RGB buffer (4 bytes per pixel: RGBA)
  size_t rgbDataSize = width * height * 4;
  uint8_t *rgbData = calloc(rgbDataSize, 1);
  if (!rgbData) {
    NSLog(@"[ImageUtils]    ❌ Failed to allocate RGB buffer");
    CGColorSpaceRelease(rgbColorSpace);
    return NULL;
  }
  
  // Fill entire buffer with WHITE (255,255,255,255)
  for (size_t i = 0; i < width * height; i++) {
    rgbData[i * 4 + 0] = 255; // R
    rgbData[i * 4 + 1] = 255; // G  
    rgbData[i * 4 + 2] = 255; // B
    rgbData[i * 4 + 3] = 255; // A
  }
  NSLog(@"[ImageUtils]    ✅ Pre-filled RGB buffer with WHITE");
  
  // Create RGB context
  CGContextRef rgbContext = CGBitmapContextCreate(
    rgbData,
    width,
    height, 
    8,
    width * 4,
    rgbColorSpace,
    kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big
  );
  
  CGColorSpaceRelease(rgbColorSpace);
  
  if (!rgbContext) {
    NSLog(@"[ImageUtils]    ❌ Failed to create RGB context");
    free(rgbData);
    return NULL;
  }
  
  // Clear with white background (redundant but explicit)
  CGContextSetRGBFillColor(rgbContext, 1.0, 1.0, 1.0, 1.0);
  CGContextFillRect(rgbContext, CGRectMake(0, 0, width, height));
  
  // Draw original image on top
  CGContextDrawImage(rgbContext, CGRectMake(0, 0, width, height), cgImage);
  
  // Sample the RGB data to verify content
  NSLog(@"[ImageUtils]    SAMPLING RGB data after drawing:");
  NSMutableString *rgbSample = [NSMutableString string];
  for (int i = 0; i < MIN(5, (int)(width * height)); i++) {
    int idx = i * 4;
    [rgbSample appendFormat:@"[%d,%d,%d,%d] ", 
     rgbData[idx], rgbData[idx+1], rgbData[idx+2], rgbData[idx+3]];
  }
  NSLog(@"[ImageUtils]    First 5 RGBA pixels: %@", rgbSample);
  
  // Check for actual content (non-white pixels)
  int nonWhitePixels = 0;
  for (size_t i = 0; i < width * height; i++) {
    int idx = i * 4;
    if (rgbData[idx] < 250 || rgbData[idx+1] < 250 || rgbData[idx+2] < 250) {
      nonWhitePixels++;
    }
  }
  NSLog(@"[ImageUtils]    Non-white pixels found: %d out of %zu", nonWhitePixels, width * height);
  
  CGContextRelease(rgbContext);

  // Now convert RGB to grayscale manually (simple luminance formula)
  size_t grayDataSize = width * height;
  uint8_t *greyData = malloc(grayDataSize);
  if (!greyData) {
    NSLog(@"[ImageUtils]    ❌ malloc failed for grayscale data");
    free(rgbData);
    return NULL;
  }
  
  NSLog(@"[ImageUtils]    Converting RGB to grayscale manually...");
  for (size_t i = 0; i < width * height; i++) {
    int idx = i * 4;
    uint8_t r = rgbData[idx];
    uint8_t g = rgbData[idx + 1]; 
    uint8_t b = rgbData[idx + 2];
    
    // Standard luminance formula (same as Android)
    uint8_t gray = (uint8_t)(0.299 * r + 0.587 * g + 0.114 * b);
    greyData[i] = gray;
  }
  
  free(rgbData);
  
  // Sample grayscale data
  NSLog(@"[ImageUtils]    SAMPLING final grayscale data:");
  NSMutableString *graySample = [NSMutableString string];
  int whiteCount = 0, blackCount = 0, grayCount = 0;
  
  for (int i = 0; i < MIN(20, (int)grayDataSize); i++) {
    uint8_t pixelValue = greyData[i];
    [graySample appendFormat:@"%d ", pixelValue];
    
    if (pixelValue < 85) blackCount++;
    else if (pixelValue > 170) whiteCount++;
    else grayCount++;
  }
  
  NSLog(@"[ImageUtils]    First 20 grayscale pixels: %@", graySample);
  NSLog(@"[ImageUtils]    Quick analysis - Black(<85): %d, Gray(85-170): %d, White(>170): %d", 
        blackCount, grayCount, whiteCount);

  NSLog(@"[ImageUtils]    ✅ SIMPLIFIED conversion complete with EXPLICIT white background (%zu bytes)", grayDataSize);

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
    
    NSLog(@"[ImageUtils]    SIZE OF SRC: %lu",sizeof(&src));
    NSInteger nBytesPerLine = (int)nWidth/8;
    NSInteger bytesPerLineWithPadding = nBytesPerLine;
    
    // Calculate padding bytes (each byte is 8 pixels)
    NSInteger paddingBytes = leftPadding / 8;
    if (leftPadding > 0) {
        bytesPerLineWithPadding += paddingBytes;
    }
    
    NSLog(@"[ImageUtils]    nBytesPerLine: %ld, paddingBytes: %ld, bytesPerLineWithPadding: %ld", 
          (long)nBytesPerLine, (long)paddingBytes, (long)bytesPerLineWithPadding);
    
    NSInteger totalSize = nHeight*(8+bytesPerLineWithPadding);
    NSLog(@"[ImageUtils]    allocating command buffer: %ld bytes", (long)totalSize);
    
    unsigned char * data = malloc(totalSize);
    if (!data) {
        NSLog(@"[ImageUtils]    ❌ malloc failed for command buffer");
        return nil;
    }
    
    NSInteger k = 0;
    
    NSLog(@"[ImageUtils]    processing %ld lines...", (long)nHeight);
    
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
        
        if (i == 0) {
            // Log first line header for debugging
            NSMutableString *headerPreview = [NSMutableString stringWithString:@""];
            for (int h = 0; h < 8; h++) {
                [headerPreview appendFormat:@"%02X ", data[var10 + h]];
            }
            NSLog(@"[ImageUtils]    Line 0 header: %@", headerPreview);
        }
    }
    
    NSLog(@"[ImageUtils]    ✅ command generation successful, total size: %ld bytes", (long)totalSize);
    
    NSData *result = [NSData dataWithBytes:data length:totalSize];
    free(data);
    
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
    
    // ⭐ SPECIAL HANDLING: Detect completely white or near-white images
    int threshold;
    int grayRange = maxGray - minGray;
    
    if (grayRange <= 5 && minGray >= 250) {
        // Completely white or near-white image (like logos on white background)
        // Use a threshold much lower than the average to detect any content
        threshold = minGray - 10; // Go below minimum to detect content
        NSLog(@"[ImageUtils]    WHITE IMAGE detected (min=%d, range=%d), using content-detection threshold", minGray, grayRange);
    } else if (grayRange <= 10 && grayave >= 240) {
        // Very light image
        threshold = grayave - 15;
        NSLog(@"[ImageUtils]    VERY LIGHT IMAGE detected, using reduced threshold");
    } else {
        // Normal image - use Android-style average threshold
        threshold = grayave;
        NSLog(@"[ImageUtils]    NORMAL IMAGE, using Android-style average threshold");
    }
    
    NSLog(@"[ImageUtils]    Gray stats - Min:%d, Max:%d, Avg:%d, Range:%d, Threshold:%d (SMART)",
          minGray, maxGray, grayave, grayRange, threshold);
    
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

+ (NSData *)fullImageToCmd:(unsigned char *)src nWidth:(NSInteger) nWidth nHeight:(NSInteger) nHeight nMode:(NSInteger) nMode leftPadding:(NSInteger) leftPadding
{
    NSLog(@"[ImageUtils] → fullImageToCmd (ANDROID-STYLE): width=%ld, height=%ld, mode=%ld, padding=%ld", 
          (long)nWidth, (long)nHeight, (long)nMode, (long)leftPadding);
    
    if (!src) {
        NSLog(@"[ImageUtils]    ❌ src data is NULL");
        return nil;
    }
    
    if (nWidth <= 0 || nHeight <= 0) {
        NSLog(@"[ImageUtils]    ❌ invalid dimensions");
        return nil;
    }
    
    NSInteger nBytesPerLine = (int)nWidth/8;
    NSInteger bytesPerLineWithPadding = nBytesPerLine;
    
    // Calculate padding bytes (each byte is 8 pixels)
    NSInteger paddingBytes = leftPadding / 8;
    if (leftPadding > 0) {
        bytesPerLineWithPadding += paddingBytes;
    }
    
    NSLog(@"[ImageUtils]    nBytesPerLine: %ld, paddingBytes: %ld, bytesPerLineWithPadding: %ld", 
          (long)nBytesPerLine, (long)paddingBytes, (long)bytesPerLineWithPadding);
    
    // ⭐ ANDROID-STYLE: Single command for entire image, not line by line
    NSInteger totalImageBytes = nHeight * bytesPerLineWithPadding;
    NSInteger totalSize = 8 + totalImageBytes; // Header (8 bytes) + image data
    NSLog(@"[ImageUtils]    ANDROID-STYLE: single command, total size: %ld bytes", (long)totalSize);
    
    unsigned char * data = malloc(totalSize);
    if (!data) {
        NSLog(@"[ImageUtils]    ❌ malloc failed for command buffer");
        return nil;
    }
    
    // ⭐ Single GS v command for entire image (like Android)
    data[0] = 29;  // GS
    data[1] = 118; // v  
    data[2] = 48;  // 0
    data[3] = (unsigned char)(nMode & 1);
    data[4] = (unsigned char)(bytesPerLineWithPadding % 256); // xL
    data[5] = (unsigned char)(bytesPerLineWithPadding / 256); // xH
    data[6] = (unsigned char)(nHeight % 256); // yL - ⭐ ENTIRE HEIGHT, not 1
    data[7] = (unsigned char)(nHeight / 256); // yH
    
    NSLog(@"[ImageUtils]    Header: GS=%d v=%d 0=%d mode=%d xL=%d xH=%d yL=%d yH=%d", 
          data[0], data[1], data[2], data[3], data[4], data[5], data[6], data[7]);
    
    // Process all image data at once
    NSInteger k = 0;
    NSInteger dataIndex = 8; // Start after header
    
    for(int i = 0; i < nHeight; i++){
        // Add padding bytes (zeros = white space) for each line
        for (int p = 0; p < paddingBytes; p++) {
            data[dataIndex++] = 0;
        }
        
        // Add actual image data after padding for each line
        for (int j = 0; j < nBytesPerLine; ++j) {
            data[dataIndex++] = (int)(p0[src[k]] + p1[src[k + 1]] + p2[src[k + 2]] + p3[src[k + 3]] + p4[src[k + 4]] + p5[src[k + 5]] + p6[src[k + 6]] + src[k + 7]);
            k = k + 8;
        }
    }
    
    NSLog(@"[ImageUtils]    ✅ ANDROID-STYLE command generation successful, single command: %ld bytes", (long)totalSize);
    
    NSData *result = [NSData dataWithBytes:data length:totalSize];
    free(data);
    
    return result;
}

@end
