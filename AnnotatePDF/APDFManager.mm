//
//  APDFManager.m
//  AnnotatePDF
//
//  Created by Felix Kopp on 7/20/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "APDFManager.h"
#import "APDFAnnotation.h"
#import "ResizableTextView.h"
#import "podofo.h"

#import "CTOpenSSLWrapper.h"
//using namespace PoDoFo;

@implementation APDFManager

+(void)createFreeTextAnnotationOnPage:(NSInteger)pageIndex doc:(PdfMemDocument*)aDoc rect:(CGRect)aRect borderWidth:(double)bWidth title:(NSString*)title content:(NSString*)content bOpen:(Boolean)bOpen color:(UIColor*)color {
    PoDoFo::PdfMemDocument *doc = (PoDoFo::PdfMemDocument *) aDoc;
    PoDoFo::PdfPage* pPage = doc->GetPage(pageIndex);
    if (! pPage) {
        // couldn't get that page
        return;
    }
    PoDoFo::PdfAnnotation* anno;
    PoDoFo::EPdfAnnotation type= PoDoFo::ePdfAnnotation_FreeText;
    
    PoDoFo::PdfRect rect;
    rect.SetBottom(aRect.origin.y);
    rect.SetLeft(aRect.origin.x);
    rect.SetHeight(aRect.size.height);
    rect.SetWidth(aRect.size.width);
    
    anno = pPage->CreateAnnotation(type , rect);
    
    PoDoFo::PdfString sTitle(reinterpret_cast<const PoDoFo::pdf_utf8*>([title UTF8String]));
    PoDoFo::PdfString sContent(reinterpret_cast<const PoDoFo::pdf_utf8*>([content UTF8String]));
    
    CGFloat red = 0.0, green = 0.0, blue = 0.0, alpha = 0.0;
    if ([color respondsToSelector:@selector(getRed:green:blue:alpha:)]) {
        [color getRed:&red green:&green blue:&blue alpha:&alpha];
    }
    
    anno->SetTitle(sTitle);
    anno->SetContents(sContent);
//    anno->SetColor(red, green, blue);
    anno->SetOpen(bOpen);
    anno->SetBorderStyle(0, 0, bWidth);
}

+(void)createSquareAnnotationOnPage:(NSInteger)pageIndex doc:(PdfMemDocument*)aDoc rect:(CGRect)aRect borderWidth:(double)bWidth title:(NSString*)title bOpen:(Boolean)bOpen color:(UIColor*)color
{
    PoDoFo::PdfMemDocument* doc = (PoDoFo::PdfMemDocument *)aDoc;
    PoDoFo::PdfPage* pPage = doc->GetPage(pageIndex);
    if (! pPage) {
        // couldn't get that page
        return;
    }
    PoDoFo::PdfAnnotation* anno;
    PoDoFo::EPdfAnnotation type= PoDoFo::ePdfAnnotation_Square;
    
    PoDoFo::PdfRect rect;
    rect.SetBottom(aRect.origin.y);
    rect.SetLeft(aRect.origin.x);
    rect.SetHeight(aRect.size.height);
    rect.SetWidth(aRect.size.width);
    
    anno = pPage->CreateAnnotation(type , rect);
    
    PoDoFo::PdfString sTitle(reinterpret_cast<const PoDoFo::pdf_utf8*>([title UTF8String]));
    
    CGFloat red = 0.0, green = 0.0, blue = 0.0, alpha = 0.0;
    
    if ([color respondsToSelector:@selector(getRed:green:blue:alpha:)]) {
        [color getRed:&red green:&green blue:&blue alpha:&alpha];
    }
    
    if (bWidth == 0) {
        bWidth = 1.0;
    }
        
    anno->SetTitle(sTitle);
    anno->SetColor(red, green, blue);
    anno->SetOpen(bOpen);
    anno->SetBorderStyle(0, 0, bWidth);
}

+(void)deleteAnnotationWithIndex:(NSInteger)annotIndex onPage:(NSInteger)pageIndex ofDoc:(PdfMemDocument *)aDoc
{
    PoDoFo::PdfMemDocument* doc = (PoDoFo::PdfMemDocument *)aDoc;
    PoDoFo::PdfPage *pPage = doc->GetPage(pageIndex);
    
    pPage->DeleteAnnotation(annotIndex);
}

+(PdfMemDocument*)createPdfForFileAtPath:(NSString*)path
{    
    PoDoFo::PdfMemDocument* doc = new PoDoFo::PdfMemDocument([path UTF8String]);
    
    return (PdfMemDocument*)doc;
}

+(NSString*)createCopyForFile:(NSString*)path
{
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    NSString *tmp = [documentsDirectory stringByAppendingPathComponent:@"/tmp.apdf"];
    
    if ([fileManager fileExistsAtPath:tmp] == YES) {
        [fileManager removeItemAtPath:tmp error:&error];
    }

    [fileManager copyItemAtPath:path toPath:tmp error:&error];
    
    return tmp;
}

+(void)writePdf:(PdfMemDocument*)aDoc toPath:(NSString *)path withTemporaryFilePath:(NSString*)tmpPath
{
    PoDoFo::PdfMemDocument* doc = (PoDoFo::PdfMemDocument *)aDoc;
    
    doc->Write([tmpPath UTF8String]);
    
//    doc->~PdfMemDocument();
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    
    if ([fileManager fileExistsAtPath:path] == YES) {
        [fileManager removeItemAtPath:path error:&error];
    }
    [fileManager copyItemAtPath:tmpPath toPath:path error:&error];
}

+(NSMutableArray *)getAnnotationsArrayForPage:(CGPDFPageRef)pPage{
    NSMutableArray* pdfAnnots = [[NSMutableArray alloc] init];
    
    CGPDFDictionaryRef pageDictionary = CGPDFPageGetDictionary(pPage);
    CGPDFArrayRef outputArray;
    if(!CGPDFDictionaryGetArray(pageDictionary, "Annots", &outputArray)) {
        [pdfAnnots release];
        return nil;
    }
    else{
        int arrayCount = CGPDFArrayGetCount( outputArray );
        for( int j = 0; j < arrayCount; ++j ) {
            CGPDFObjectRef aDictObj;
            if(!CGPDFArrayGetObject(outputArray, j, &aDictObj)) {
                break;
            }
            
            CGPDFDictionaryRef annotDict;
            if(!CGPDFObjectGetValue(aDictObj, kCGPDFObjectTypeDictionary, &annotDict)) {
                break;
            }
            
            const char *annotationType;
            CGPDFDictionaryGetName(annotDict, "Subtype", &annotationType);
            
            NSString* type = [NSString stringWithUTF8String:annotationType];
            
            CGPDFArrayRef rectArray;
            if(!CGPDFDictionaryGetArray(annotDict, "Rect", &rectArray)) {
                break;
            }
            
            int arrayCount = CGPDFArrayGetCount( rectArray );
            CGPDFReal coords[4];
            for( int k = 0; k < arrayCount; ++k ) {
                CGPDFObjectRef rectObj;
                if(!CGPDFArrayGetObject(rectArray, k, &rectObj)) {
                    break;
                }
                
                CGPDFReal coord;
                if(!CGPDFObjectGetValue(rectObj, kCGPDFObjectTypeReal, &coord)) {
                    break;
                }
                
                coords[k] = coord;
            }               
            
            CGRect rect = CGRectMake(coords[0],coords[1],coords[2],coords[3]);
            
            UIColor *annotColor = [UIColor blackColor];
            CGPDFArrayRef colorArray;
            if(CGPDFDictionaryGetArray(annotDict, "C", &colorArray)) {
                int cArrayCount = CGPDFArrayGetCount( colorArray );
                CGPDFReal colors[3];
                for( int k = 0; k < cArrayCount; ++k ) {
                    CGPDFObjectRef colorObj;
                    if(!CGPDFArrayGetObject(colorArray, k, &colorObj)) {
                        break;
                    }
                    CGPDFReal color;
                    if(!CGPDFObjectGetValue(colorObj, kCGPDFObjectTypeReal, &color)) {
                        break;
                    }
                    colors[k] = color;
                }               
                annotColor=[UIColor colorWithRed:colors[0] green:colors[1] blue:colors[2] alpha:1]; 
                
            }          
            rect.size.width -= rect.origin.x;
            rect.size.height -= rect.origin.y;
            
            //to show the annotation on the right position a +5 is needed. It may
            //be needed because the content inset Top of the ResizableTextView is set 
            //to -5 ?Dont know why this effects the y value of the frame?
            rect.origin.y +=5;
            
            APDFAnnotation *annotation = [[APDFAnnotation alloc] initWithPDFDictionary:annotDict andType:type];
            annotation.annotColor = annotColor;
            
            // FreeText annotations are identified by FreeText name stored in Subtype key in annotation dictionary.
            if ([type isEqualToString:ANNOT_FREE_TEXT]){                
                ResizableTextView *annotationView = [[ResizableTextView alloc] initWithFrame:CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height)];
                annotationView.font = annotation.font;
                annotationView.text = annotation.textString;
                annotationView.textColor = annotation.textColor;
                annotationView.backgroundColor = [UIColor clearColor];
                annotationView.textAlignment = annotation.textAlignment;
                [annotationView setEditable:YES];
                
                if (annotation.borderWidth != 0) {
                    annotationView.layer.borderColor = annotation.textColor.CGColor;
                    annotationView.layer.borderWidth = annotation.borderWidth;
                }
                
                annotation.annotationView = annotationView;
                [annotationView release];
            }else if ([type isEqualToString:ANNOT_SQUARE]){
                ResizableTextView *squareView = [[ResizableTextView alloc] initWithFrame:rect];
                squareView.backgroundColor = [UIColor clearColor];
                squareView.layer.borderColor = annotColor.CGColor;
                squareView.layer.borderWidth = annotation.borderWidth;
                
                annotation.annotationView = squareView;
                [squareView release];
            }else if([type isEqualToString:ANNOT_HIGHLIGHT]){
                ResizableTextView *highlightView = [[ResizableTextView alloc] initWithFrame:rect];
                highlightView.backgroundColor=annotColor;
                highlightView.alpha = 0.5;
                
                annotation.annotationView = highlightView;
                [highlightView release];
            }else{
            // you may support more annotations
            }
            
            [pdfAnnots addObject:annotation];
            [annotation release];
        }
    }
    return [pdfAnnots autorelease];
}

+(NSArray *)getPdfPathsOfArray:(NSArray *)paths{
    NSMutableArray* resultArray = [NSMutableArray array];
    for (int i=0; i<[paths count]; i++) {
        NSString* path = (NSString*)[paths objectAtIndex:i];
        if ([path hasSuffix:@".pdf"]) {
            [resultArray addObject:path];
        }
    }
    paths = [NSArray arrayWithArray:resultArray];
    return paths;
}


#define CONVERSION_CONSTANT 0.002834645669291339
//using namespace PoDoFo;

/* Common defines needed in all tests */
#define TEST_SAFE_OP( x ) try {  x; } catch( PoDoFo::PdfError & e ) { \
e.AddToCallstack( __FILE__, __LINE__, NULL ); \
e.PrintErrorMsg();\
/*return*/ e.GetError();\
}


#define TEST_SAFE_OP_IGNORE( x ) try {  x; } catch( PoDoFo::PdfError & e ) { \
e.AddToCallstack( __FILE__, __LINE__, NULL ); \
e.PrintErrorMsg();\
}

#pragma mark -
#pragma mark Digital signatures
void CreateSimpleForm( PoDoFo::PdfPage* pPage, PoDoFo::PdfStreamedDocument* pDoc, const PoDoFo::PdfData &signatureData )
{
    PoDoFo::PdfPainter painter;
    PoDoFo::PdfFont*   pFont = pDoc->CreateFont( "Courier" );
    
    painter.SetPage( pPage );
    painter.SetFont( pFont );
    painter.DrawText( 10000 * CONVERSION_CONSTANT, 280000 * CONVERSION_CONSTANT, "PoDoFo Sign Test" );
    painter.FinishPage();
    
	PoDoFo::PdfSignatureField signField( pPage, PoDoFo::PdfRect( 70000 * CONVERSION_CONSTANT, 10000 * CONVERSION_CONSTANT,
                                                                50000 * CONVERSION_CONSTANT, 50000 * CONVERSION_CONSTANT ), pDoc );
    signField.SetFieldName("SignatureFieldName");
	signField.SetSignature(signatureData);
	signField.SetSignatureReason("I agree");
	// Set time of signing
	signField.SetSignatureDate( PoDoFo::PdfDate() );
}

+(void)addDigitalSignatureOnPage:(NSInteger)pageIndex outpath:(NSString*)path/*doc:(PoDoFo::PdfMemDocument*)aDoc*/{
    PoDoFo::PdfPage*            pPage;
    
    
    PoDoFo::PdfSignOutputDevice signer([path UTF8String]);
	// Reserve space for signature
    signer.SetSignatureSize(1024);
    
	PoDoFo::PdfStreamedDocument writer( &signer, PoDoFo::ePdfVersion_1_5 );
    // Disable default appearance
    writer.GetAcroForm(PoDoFo::ePdfCreateObject, PoDoFo::PdfAcroForm::ePdfAcroFormDefaultAppearance_None);
    
    pPage = writer.CreatePage(PoDoFo::PdfPage::CreateStandardPageSize(PoDoFo::ePdfPageSize_A4 ) );
    TEST_SAFE_OP( CreateSimpleForm( pPage, &writer, *signer.GetSignatureBeacon() ) );
    
    TEST_SAFE_OP( writer.Close() );
    
    // Check if position of signature was found
    if(signer.HasSignaturePosition()) {
		// Adjust ByteRange for signature
        signer.AdjustByteRange();
		
		// Read data for signature and count it
		// We have to seek at the beginning of the file
		signer.Seek(0);
        
		// Generate digest and count signature
		// use NSS, MS Crypto API or OpenSSL
		// to generate signature in DER format
        
		// This is example of generation process
		// with dummy generator. Check example for
		// NSS generator
		/*
         SimpleSignatureGenerator sg;
         
         // Read data to be signed and send them to the
         // signature generator
         char buff[65536];
         size_t len;
         while( (len = signer.ReadForSignature(buff, 65536))>0 )
         {
         sg.appendData(buff, len);
         }
         sg.finishData();
         
         // Paste signature to the file
         const PdfData *pSignature = sg.getSignature();
         */
        /*
         CERTCertificate* pCert = read_cert();
         NSSSignatureGenerator ng(pCert);
         char buff[65536];
         size_t len;
         while( (len = signer.ReadForSignature(buff, 65536))>0 )
         {
         ng.appendData(buff, len);
         }
         ng.finishData();
         
         // Paste signature to the file
         const PoDoFo::PdfData *pSignature = ng.getSignature();
         
         CERT_DestroyCertificate(pCert);
         
         if(pSignature!=NULL) {
         signer.SetSignature(*pSignature);
         }
         */
        
        
        /*char buff[65536];
         size_t len;
         while( (len = signer.ReadForSignature(buff, 65536))>0 )
         {
         }*/
        
        
        NSData *privateKeyData = CTOpenSSLGeneratePrivateRSAKey(1024, CTOpenSSLPrivateKeyFormatPEM);
      //NSData *publicKeyData = CTOpenSSLExtractPublicKeyFromPrivateRSAKey(privateKeyData);
        NSData *rawData = [NSData dataWithContentsOfFile:path];
        NSData *signature = CTOpenSSLRSASignWithPrivateKey(privateKeyData, rawData, CTOpenSSLDigestTypeSHA512);
        
        NSString* signatureStr = [[NSString alloc] initWithData:signature encoding:NSUTF8StringEncoding];
        
        // Paste signature to the file
        PoDoFo::PdfData sigData([signatureStr UTF8String]);
        signer.SetSignature(sigData);
        
        
    }
    
	signer.Flush();
}

@end
