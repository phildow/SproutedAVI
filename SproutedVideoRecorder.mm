//
//  SproutedVideoRecorder.mm
//  Sprouted AVI
//
//  Created by Philip Dow on xx.
//  Copyright Philip Dow / Sprouted. All rights reserved.
//	All inquiries should be directed to developer@journler.com
//

/*
 Redistribution and use in source and binary forms, with or without modification, are permitted
 provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions
 and the following disclaimer in the documentation and/or other materials provided with the
 distribution.
 
 * Neither the name of the author nor the names of its contributors may be used to endorse or
 promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
 WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
 ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
 TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/


#import <SproutedAVI/SproutedVideoRecorder.h>
#import <SproutedAVI/SproutedAVIAlerts.h>
#import <SproutedAVI/PDMeteringView.h>

#define BailErr(x) {err = x; if(err != noErr) goto bail;}

static const char * rFILE(const char * inStr) { 
		int count = strlen(inStr); 
		while (count && *(inStr + count - 1) != '/')
			count--;
		return inStr + count;
	}


#define BAILERR( x )        do {                                                                                            \
									OSStatus tErr = (x);																		\
									if ( tErr ) {                                                                               \
										fprintf(stderr, "%s:%d:%s ### Err %ld\n", rFILE(__FILE__), __LINE__, __func__, tErr);	\
										goto bail;                                                                              \
									}                                                                                           \
								} while (0)

#define kMeterTimerInterval			1.0/15
#define kPlaybacklockTimerInterval	1.0/30

#define kEncodingStringMPG4 @"MPEG4 320x240 AAC 128k"
#define kEncodingStringH264 @"H.264 320x240 AAC 128k"

#define kEncodingOptionH264		0
#define kEncodingOptionMPEG4	1

#pragma mark -

static OSStatus createCompressionSession( 
		int width, 
		int height, 
		CodecType codecType, 
		SInt32 averageDataRate, 
		TimeScale timeScale, 
		ICMEncodedFrameOutputCallback outputCallback, 
		void *outputRefCon,
		ICMCompressionSessionRef *compressionSessionOut )
{
	OSStatus err = noErr;
	ICMEncodedFrameOutputRecord encodedFrameOutputRecord = {0};
	ICMCompressionSessionOptionsRef sessionOptions = NULL;
	
	err = ICMCompressionSessionOptionsCreate( NULL, &sessionOptions );
	if( err ) {
		NSLog(@"ICMCompressionSessionOptionsCreate() failed (%d)", err );
		goto bail;
	}
	
	// We must set this flag to enable P or B frames.			***
	err = ICMCompressionSessionOptionsSetAllowTemporalCompression( sessionOptions, true );
	if( err ) {
		NSLog(@"ICMCompressionSessionOptionsSetAllowTemporalCompression() failed (%d)", err );
		goto bail;
	}
	
	// We must set this flag to enable B frames.				***
	err = ICMCompressionSessionOptionsSetAllowFrameReordering( sessionOptions, true );
	if( err ) {
		NSLog(@"ICMCompressionSessionOptionsSetAllowFrameReordering() failed (%d)", err );
		goto bail;
	}
	
	// Set the maximum key frame interval, also known as the key frame rate.
	err = ICMCompressionSessionOptionsSetMaxKeyFrameInterval( sessionOptions, 30 );
	if( err ) {
		NSLog(@"ICMCompressionSessionOptionsSetMaxKeyFrameInterval() failed (%d)", err );
		goto bail;
	}

	// This allows the compressor more flexibility (ie, dropping and coalescing frames).
	err = ICMCompressionSessionOptionsSetAllowFrameTimeChanges( sessionOptions, true );
	if( err ) {
		NSLog(@"ICMCompressionSessionOptionsSetAllowFrameTimeChanges() failed (%d)", err );
		goto bail;
	}
	
	// We need durations when we store frames.
	err = ICMCompressionSessionOptionsSetDurationsNeeded( sessionOptions, true );
	if( err ) {
		NSLog(@"ICMCompressionSessionOptionsSetDurationsNeeded() failed (%d)", err );
		goto bail;
	}
	
	// Set the average data rate.
	err = ICMCompressionSessionOptionsSetProperty( sessionOptions, 
				kQTPropertyClass_ICMCompressionSessionOptions,
				kICMCompressionSessionOptionsPropertyID_AverageDataRate,
				sizeof( averageDataRate ),
				&averageDataRate );
	if( err ) {
		NSLog(@"ICMCompressionSessionOptionsSetProperty(AverageDataRate) failed (%d)", err );
		goto bail;
	}
	
	encodedFrameOutputRecord.encodedFrameOutputCallback = outputCallback;
	encodedFrameOutputRecord.encodedFrameOutputRefCon = outputRefCon;
	encodedFrameOutputRecord.frameDataAllocator = NULL;
	
	NSMutableDictionary *pixelBufferAttribs = [[NSMutableDictionary alloc] init];
			
	//don't pass width and height.  Let the codec make a best guess as to the appropriate
	//width and height for the given quality.  It might choose to do a quarter frame decode,
	//for instance
	
	[pixelBufferAttribs setObject:[NSNumber numberWithFloat:320] forKey:(id)kCVPixelBufferWidthKey];
	[pixelBufferAttribs setObject:[NSNumber numberWithFloat:240] forKey:(id)kCVPixelBufferHeightKey];
	[pixelBufferAttribs setObject:[NSNumber numberWithInt:k32ARGBPixelFormat] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
	[pixelBufferAttribs setObject:[NSNumber numberWithBool:YES] forKey:(id)kCVPixelBufferCGBitmapContextCompatibilityKey];
	[pixelBufferAttribs setObject:[NSNumber numberWithBool:YES] forKey:(id)kCVPixelBufferCGImageCompatibilityKey];
	
	//[pixelBufferAttribs setObject:[NSNumber numberWithBool:YES] forKey:(id)kCVPixelBufferOpenGLCompatibilityKey];
	
	err = ICMCompressionSessionCreate( NULL, 
			width, 
			height, 
			codecType, 
			timeScale,
			sessionOptions, 
			(CFDictionaryRef)pixelBufferAttribs, /*NULL*/
			&encodedFrameOutputRecord, 
			compressionSessionOut );
			
	if( err ) {
		NSLog(@"ICMCompressionSessionCreate() failed (%d)", err );
		goto bail;
	}
	
bail:

	ICMCompressionSessionOptionsRelease( sessionOptions );
	[pixelBufferAttribs release];
	return err;
}


// Create a video track and media to hold encoded frames.
// This is called the first time we get an encoded frame back from the compression session.
static OSStatus createVideoMedia( 
		PDCaptureRecordPtr captureData,
		ImageDescriptionHandle imageDesc,
		TimeScale timescale )
{
	OSStatus err = noErr;
	Fixed trackWidth, trackHeight;
	Track outputTrack = NULL;
	
	err = ICMImageDescriptionGetProperty( 
			imageDesc,
			kQTPropertyClass_ImageDescription, 
			kICMImageDescriptionPropertyID_ClassicTrackWidth,
			sizeof( trackWidth ),
			&trackWidth,
			NULL );
			
	if( err ) {
		NSLog(@"ICMImageDescriptionGetProperty(kICMImageDescriptionPropertyID_DisplayWidth) failed (%d)", err );
		goto bail;
	}
	
	err = ICMImageDescriptionGetProperty( 
			imageDesc,
			kQTPropertyClass_ImageDescription, 
			kICMImageDescriptionPropertyID_ClassicTrackHeight,
			sizeof( trackHeight ),
			&trackHeight,
			NULL );
			
	if( err ) {
		NSLog(@"ICMImageDescriptionGetProperty(kICMImageDescriptionPropertyID_DisplayHeight) failed (%d)", err );
		goto bail;
	}
	
	outputTrack = NewMovieTrack( captureData->outputMovie, trackWidth, trackHeight, 0 );
	err = GetMoviesError();
	
	if( err ) {
		NSLog(@"NewMovieTrack() failed (%d)", err );
		goto bail;
	}
	
	#warning neeed a corresponding DisposeTrackMedia?
	captureData->videoMedia = NewTrackMedia( outputTrack, VideoMediaType, timescale, 0, 0 );
	err = GetMoviesError();
	
	if( err ) {
		NSLog(@"NewTrackMedia() failed (%d)", err );
		goto bail;
	}
	
	err = BeginMediaEdits( captureData->videoMedia );
	if( err ) {
		NSLog(@"BeginMediaEdits() failed (%d)", err );
		goto bail;
	}
	captureData->didBeginVideoMediaEdits = true;
	
bail:
	return err;
}

#pragma mark -

static void releaseAndUnlockThis( void *info, const void *data, size_t size )
{
	CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)info;
	CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
	CVBufferRelease( pixelBuffer );
}


static CGImageRef createCGImageFrom32XRGBCVPixelBuffer( void *decompressionTrackingRefCon, CVPixelBufferRef pixelBuffer )
{
	static size_t width = 320, height = 240;
	//static size_t width = 640, height = 480;
	size_t rowBytes;
	void *baseAddr = NULL;
	CGDataProviderRef provider = NULL;
	CGImageRef image = NULL;
	
	PDCaptureRecordPtr captureData = (PDCaptureRecordPtr)decompressionTrackingRefCon;
	
	CVPixelBufferLockBaseAddress( pixelBuffer, 0 );
	
	rowBytes = CVPixelBufferGetBytesPerRow( pixelBuffer );
	baseAddr = CVPixelBufferGetBaseAddress( pixelBuffer );
	
	width = CVPixelBufferGetWidth( pixelBuffer );
	height = CVPixelBufferGetHeight( pixelBuffer );
	
	CVBufferRetain( pixelBuffer );
	provider = CGDataProviderCreateWithData( pixelBuffer, 
			baseAddr, 
			rowBytes * height, 
			releaseAndUnlockThis );
			
	image = CGImageCreate( width, height, 
			8, 32, 
			rowBytes, 
			captureData->colorspace, 
			kCGImageAlphaNoneSkipFirst, 
			provider, 
			NULL, 
			true, 
			kCGRenderingIntentDefault );
	
bail:

	if( provider ) CGDataProviderRelease( provider );
	return image;
}


// The tracking callback function for the decompression session.
// Draw on pixel buffers, display them in the window and feed them to the compression session.
static void displayAndCompressFrame( 
		void *decompressionTrackingRefCon,
		OSStatus result,
		ICMDecompressionTrackingFlags decompressionTrackingFlags,
		CVPixelBufferRef pixelBuffer,
		TimeValue64 displayTime,
		TimeValue64 displayDuration,
		ICMValidTimeFlags validTimeFlags,
		void *reserved,
		void *sourceFrameRefCon )
{
	
	OSStatus err = noErr;
	PDCaptureRecordPtr captureData = (PDCaptureRecordPtr)decompressionTrackingRefCon;
	
	// Display the frame if not dropping it according to the preview frame rate
	// draws the frame directly to the window as graphics context
	if ( !captureData->dropFrame ) 
	{
		CGImageRef image = NULL;
		image = createCGImageFrom32XRGBCVPixelBuffer( captureData , pixelBuffer );
		if( image ) { 
			CGContextDrawImage ( captureData->graphicsContext, captureData->targetRect, image );
			CGImageRelease( image );
		}
	}
	
	// send the frame to compression and write if recording
	if( ( kICMDecompressionTracking_EmittingFrame & decompressionTrackingFlags ) && pixelBuffer ) 
	{
		ICMCompressionFrameOptionsRef frameOptions = NULL;
		
		if ( captureData->recording ) 
		{
			// Feed the frame to the compression session.
			err = ICMCompressionSessionEncodeFrame( captureData->compressionSession, 
					pixelBuffer,
					displayTime, 
					displayDuration, 
					validTimeFlags,
					frameOptions, 
					NULL, 
					NULL );
					
			if( err ) {
				NSLog(@"ICMCompressionSessionEncodeFrame() failed (%d)", err );
			}
		}
	}
}

#pragma mark -

static OSStatus CCWriteEncodedFrameToMovie( void *encodedFrameOutputRefCon, 
				   ICMCompressionSessionRef session, 
				   OSStatus err,
				   ICMEncodedFrameRef encodedFrame,
				   void *reserved )
{
	PDCaptureRecordPtr captureData = (PDCaptureRecordPtr)encodedFrameOutputRefCon;
	ImageDescriptionHandle imageDesc = NULL;
	TimeValue64 decodeDuration;
	
	if( err ) {
		NSLog(@"writeEncodedFrameToMovie received an error (%d)", err );
		goto bail;
	}
	
	err = ICMEncodedFrameGetImageDescription( encodedFrame, &imageDesc );
	if( err ) {
		NSLog(@"ICMEncodedFrameGetImageDescription() failed (%d)", err );
		goto bail;
	}
	
	if( ! captureData->videoMedia ) {
		err = createVideoMedia( captureData, imageDesc, ICMEncodedFrameGetTimeScale( encodedFrame ) );
		if( err ) 
			goto bail;
	}
	
	decodeDuration = ICMEncodedFrameGetDecodeDuration( encodedFrame );
	if( decodeDuration == 0 ) {
		// You can't add zero-duration samples to a media.  If you try you'll just get invalidDuration back.
		// Because we don't tell the ICM what the source frame durations are,
		// the ICM calculates frame durations using the gaps between timestamps.
		// It can't do that for the final frame because it doesn't know the "next timestamp"
		// (because in this example we don't pass a "final timestamp" to ICMCompressionSessionCompleteFrames).
		// So we'll give the final frame our minimum frame duration.
		decodeDuration = captureData->minimumFrameDuration * ICMEncodedFrameGetTimeScale( encodedFrame ) / captureData->timeScale;
	}
	
	// Note: if you don't need to intercept any values, you could equivalently call:
	 err = AddMediaSampleFromEncodedFrame( captureData->videoMedia, encodedFrame, NULL );
	 if( err ) {
	     NSLog(@"AddMediaSampleFromEncodedFrame() failed (%d)", err );
	     goto bail;
	 }
	 
	 captureData->length+=(long)ICMEncodedFrameGetDataSize( encodedFrame );

	
bail:
	return err;
}

static OSStatus CCWriteAudioToMovie(PDCaptureRecordPtr captureData, 
		UInt8 *p, 
		long len, 
		long *offset, 
		TimeValue time, 
		long chRefCon)
{
    OSStatus err = noErr;
    UInt32 numSamples = 0;
    
	if (!captureData)
		return -1;
	
	if (captureData->soundMedia == NULL)
	{
        Track t;
        // Get the timescale
        err = SGGetChannelTimeScale(captureData->audioChan, &captureData->audioTimeScale);
        if ( err ) {
            NSLog(@"SGGetChannelTimeScale(audioChan) failed (%d)", err );
            goto bail;
        }
        
		// create the sound track
        t = NewMovieTrack(captureData->outputMovie, 0, 0, kFullVolume);
        err = GetMoviesError();
        if ( err ) {
            NSLog(@"NewMovieTrack(SoundMediaType) failed (%d)", err );
            goto bail;
        }
        
        captureData->soundMedia = NewTrackMedia(t, SoundMediaType, captureData->audioTimeScale, NULL, 0);
        err = GetMoviesError();
        if ( err ) {
            fprintf(stderr, "NewTrackMedia(SoundMediaType) failed (%d)", err );
            goto bail;
        }
        
        err = BeginMediaEdits( captureData->soundMedia );
        if( err ) {
            NSLog(@"BeginMediaEdits(soundMedia) failed (%d)", err );
            goto bail;
        }
        captureData->didBeginSoundMediaEdits = true;
        
        // cache the sound sample description
        err = QTGetComponentProperty(captureData->audioChan, 
				kQTPropertyClass_SGAudio,
                kQTSGAudioPropertyID_SoundDescription, 
				sizeof(captureData->audioDescH),
                &captureData->audioDescH, 
				NULL);
				
        if ( err ) {
            NSLog(@"QTGetComponentProperty(kQTSGAudioPropertyID_SoundDescription) failed (%d)", err );
            goto bail;
        }
        
        // and get the AudioStreamBasicDescription equivalent (see CoreAudioTypes.h for more info on this struct)
        err = QTSoundDescriptionGetProperty(captureData->audioDescH, 
				kQTPropertyClass_SoundDescription,
                kQTSoundDescriptionPropertyID_AudioStreamBasicDescription,
                sizeof(captureData->asbd), 
				&captureData->asbd, 
				NULL);
				
        if ( err ) {
            NSLog(@"QTSoundDescriptionGetProperty(ASBD) failed (%d)", err );
            goto bail;
        }
	}
    
	// this is a simplistic calculation of number of samples -- we presuppose that the samples are
	// PCM, and therefore all the same duration, and individually addressable.  This calculation 
	// works for PCM and CBR compressed formats.  For VBR formats (such as AAC), an array of 
	// AudioStreamPacketDescriptions accompanies each blob of audio packets (you'll find them
	// wrapped in a CFDataRef in the sgdataproc's chRefCon parameter).  If you are writing
	// VBR data, you must call AddMediaSample2 for each AudioStreamPacketDescription.
        
	if ( captureData->asbd.mBytesPerPacket )
	{
		numSamples = (len / captureData->asbd.mBytesPerPacket) * captureData->asbd.mFramesPerPacket;

		err = AddMediaSample2(  captureData->soundMedia,          // the Media
				p,                              // const UInt8 * dataIn
				len,                            // ByteCount size
				1,                              // TimeValue64 decodeDurationPerSample
				0,                              // TimeValue64 displayOffset
				(SampleDescriptionHandle)captureData->audioDescH, // SampleDescriptionHandle sampleDescriptionH
				numSamples,                     // ItemCount numberOfSamples
				0,                              // MediaSampleFlags sampleFlags
				NULL );                         // TimeValue64 * sampleDecodeTimeOut
				
		if( err ) {
			NSLog(@"AddMediaSample2(soundMedia) failed (%d)", err );
			goto bail;
		}
		
		captureData->length+=len;
		
	}
	else {
		
		AudioStreamPacketDescription * aspd = (chRefCon ? (AudioStreamPacketDescription*)CFDataGetBytePtr((CFDataRef)chRefCon) : NULL);
		numSamples = CFDataGetLength((CFDataRef)chRefCon) / sizeof(AudioStreamPacketDescription);
		UInt32 i;

		for (i = 0; i < numSamples; i++)
		{
			err = AddMediaSample2(  captureData->soundMedia, 
					p + aspd[i].mStartOffset, 
					aspd[i].mDataByteSize,
					captureData->asbd.mFramesPerPacket, 
					0, 
					(SampleDescriptionHandle)captureData->audioDescH, 
					1, 
					0, 
					NULL );
					
			if ( err ) {
				NSLog(@"AddMediaSample2(soundMedia) #%lu of %lu failed (%d)", i, numSamples, err );
				goto bail;
			}
			
			captureData->length+=aspd[i].mDataByteSize;
		}
		
		if ( chRefCon )
			CFRelease((CFDataRef)chRefCon);
	}
     	
    
bail:
    return err;
	
	
}

#pragma mark -

pascal OSErr GrabDataProc(SGChannel c, 
		Ptr p, 
		long len, 
		long *offset, 
		long chRefCon, 
		TimeValue time, 
		short writeType, 
		long refCon) {
	
	ICMFrameTimeRecord frameTime = {{0}};
	OSErr err = noErr;
	
	PDCaptureRecordPtr captureData = (PDCaptureRecordPtr)refCon;
    if (c == captureData->videoChan)
    {
		
		//
		// if we are dealing with video data
		
		
		// reset frame and time counters after a stop/start
		
		if (captureData->lastTime > time) {
			captureData->lastTime = 0;
			captureData->frameCount = 0;
		}
		
		
		if (captureData->timeScale == 0) {
			// first time here so set the time scale
			err = SGGetChannelTimeScale(c, &captureData->timeScale);
			if ( err ) {
				NSLog(@"SGGetChannelTimeScale (%d)", err );
				goto bail;
			}
			
			// Work out how much to throttle frame times
			captureData->minimumFrameDuration = captureData->timeScale / captureData->desiredFramesPerSecond;
		}
		
		
		//
		// find out if we should drop this frame for display
		if (captureData->mDesiredPreviewFrameRate)
		{
			TimeValue timeValue;
			if (captureData->mMinPreviewFrameDuration == 0)
				captureData->mMinPreviewFrameDuration = (TimeValue)(captureData->timeScale/captureData->mDesiredPreviewFrameRate);
				
			// round times to a multiple of the frame rate
			int n = (int)floor( ( ((float)time) * captureData->mDesiredPreviewFrameRate / captureData->timeScale ) + 0.5 );
			timeValue = (TimeValue)(n * captureData->timeScale / captureData->mDesiredPreviewFrameRate);
			
			if ( (captureData->lastTime > 0) && (timeValue < captureData->lastTime + captureData->mMinPreviewFrameDuration) )
				// drop the frame
				captureData->dropFrame = TRUE;
			else
				// display the frame
				captureData->dropFrame = FALSE;
		}
		

		
		captureData->frameCount++;
			
		if (captureData->compressionSession == NULL) {
			// Set up a compression session that will compress each frame and call 
			// writeEncodedFrameToMovie with each output frame.
			err = createCompressionSession( 
					captureData->width, 
					captureData->height, 
					captureData->codecType, 
					captureData->averageDataRate, 
					captureData->timeScale,
					CCWriteEncodedFrameToMovie, 
					captureData,
					&captureData->compressionSession );
					
			if ( err ) {
				NSLog(@"SGGetChannelTimeScale (%d)", err );
				goto bail;
			}
		}
		
		if (captureData->decompressionSession == NULL) {
			// Set up decompression session
			
			ImageDescriptionHandle imageDesc = (ImageDescriptionHandle)NewHandle(0);
			NSRect srcRect = NSMakeRect(0,0,320,240), imageRect = {0};
			NSMutableDictionary * pixelBufferAttribs = nil;
			ICMDecompressionTrackingCallbackRecord trackingCallbackRecord;
			ICMDecompressionSessionOptionsRef sessionOptions = NULL;
			SInt32 displayWidth, displayHeight;
			
			if ( noErr != (err = SGGetChannelSampleDescription(captureData->videoChan, (Handle)imageDesc)) )
			{
				DisposeHandle((Handle)imageDesc);
				BAILERR(err);
			}
			
			// Get the display width and height (the clean aperture width and height
			// suitable for display on a square pixel display like a computer monitor)
			if (noErr != ICMImageDescriptionGetProperty(imageDesc, 
					kQTPropertyClass_ImageDescription,
					kICMImageDescriptionPropertyID_DisplayWidth,
					sizeof(displayWidth),
					&displayWidth, 
					NULL) )
				displayWidth = (**imageDesc).width;
			
			if (noErr != ICMImageDescriptionGetProperty(imageDesc, 
					kQTPropertyClass_ImageDescription,
					kICMImageDescriptionPropertyID_DisplayHeight,
					sizeof(displayHeight), 
					&displayHeight, 
					NULL) )
				displayHeight = (**imageDesc).height;
				
			imageRect = NSMakeRect(0., 0., (float)displayWidth, (float)displayHeight);
			
			// the view to which we will be drawing accepts CIImage's.  As of QuickTime 7.0,
			// the CIImage * class does not apply gamma correction information present in
			// the ImageDescription unless there is also NCLCColorInfo to go with it.
			// We'll check here for the presence of this extension, and add a default if
			// we don't find one (we'll restrict this slam to 2vuy pixel format).
			if ( (**imageDesc).cType == '2vuy' )
			{
				OSStatus tryErr;
				NCLCColorInfoImageDescriptionExtension nclc;
				
				tryErr = ICMImageDescriptionGetProperty(imageDesc, 
						kQTPropertyClass_ImageDescription, 
						kICMImageDescriptionPropertyID_NCLCColorInfo, 
						sizeof(nclc), 
						&nclc, 
						NULL);
						
				if( noErr != tryErr ) {
					// Assume NTSC
					nclc.colorParamType = kVideoColorInfoImageDescriptionExtensionType;
					nclc.primaries = kQTPrimaries_SMPTE_C;
					nclc.transferFunction = kQTTransferFunction_ITU_R709_2;
					nclc.matrix = kQTMatrix_ITU_R_601_4;
					ICMImageDescriptionSetProperty(imageDesc, 
							kQTPropertyClass_ImageDescription, 
							kICMImageDescriptionPropertyID_NCLCColorInfo, 
							sizeof(nclc), 
							&nclc);
				}
			}
		
			pixelBufferAttribs = [[NSMutableDictionary alloc] init];
			
			//don't pass width and height.  Let the codec make a best guess as to the appropriate
			//width and height for the given quality.  It might choose to do a quarter frame decode,
			//for instance
			
			[pixelBufferAttribs setObject:[NSNumber numberWithFloat:imageRect.size.width] forKey:(id)kCVPixelBufferWidthKey];
			[pixelBufferAttribs setObject:[NSNumber numberWithFloat:imageRect.size.height] forKey:(id)kCVPixelBufferHeightKey];
			[pixelBufferAttribs setObject:[NSNumber numberWithInt:k32ARGBPixelFormat] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
			[pixelBufferAttribs setObject:[NSNumber numberWithBool:YES] forKey:(id)kCVPixelBufferCGBitmapContextCompatibilityKey];
			[pixelBufferAttribs setObject:[NSNumber numberWithBool:YES] forKey:(id)kCVPixelBufferCGImageCompatibilityKey];
			
			//[pixelBufferAttribs setObject:[NSNumber numberWithBool:YES] forKey:(id)kCVPixelBufferOpenGLCompatibilityKey];
			
			// assign a tracking callback
			trackingCallbackRecord.decompressionTrackingCallback = displayAndCompressFrame;
			trackingCallbackRecord.decompressionTrackingRefCon = captureData;
			
			// we also need to create a ICMDecompressionSessionOptionsRef to fill in codec quality
			CodecQ previewQuality = captureData->previewQuality;
			
			err = ICMDecompressionSessionOptionsCreate(NULL, &sessionOptions);
			if (err == noErr)
			{
				ICMDecompressionSessionOptionsSetProperty(sessionOptions,
						kQTPropertyClass_ICMDecompressionSessionOptions,
						kICMDecompressionSessionOptionsPropertyID_Accuracy,
						sizeof(CodecQ), 
						&previewQuality);
			}
			
			// now make a new decompression session to decode source video frames
			// to pixel buffers
			err = ICMDecompressionSessionCreate(NULL, 
					imageDesc, 
					sessionOptions, // no session options
					(CFDictionaryRef)pixelBufferAttribs, 
					&trackingCallbackRecord, 
					&captureData->decompressionSession);
			
			
			[pixelBufferAttribs release];
			ICMDecompressionSessionOptionsRelease(sessionOptions);
			DisposeHandle((Handle)imageDesc);

			BAILERR(err);

		}
		
		frameTime.recordSize = sizeof(ICMFrameTimeRecord);
		*(TimeValue64 *)&frameTime.value = time;
		frameTime.scale = captureData->timeScale;
		frameTime.rate = fixed1;
		frameTime.frameNumber = captureData->frameCount;
		frameTime.flags = icmFrameTimeIsNonScheduledDisplayTime;
		
		
		// Push encoded frame in.
		err = ICMDecompressionSessionDecodeFrame( captureData->decompressionSession,
				(UInt8 *)p, 
				len, 
				NULL, 
				&frameTime, 
				captureData );
				
		if ( err ) {
				
			NSLog(@"ICMDecompressionSessionDecodeFrame (%d)", err );
			goto bail;

		}
		
		// Pull decoded frame out.
		ICMDecompressionSessionSetNonScheduledDisplayTime( captureData->decompressionSession, 
				time, 
				captureData->timeScale, 
				0 );
		
		captureData->lastTime = time;

		
    }
	else if ( c == captureData->audioChan ) {
		
		// if we are dealing with audio data
		// 1. if recording write the data
		if ( captureData->recording ) {
			return (CCWriteAudioToMovie(captureData, (UInt8 *)p, len, offset, time, chRefCon));
		}
	}
	

bail:
	return err;
	
}

#pragma mark -

@implementation SproutedVideoRecorder

- (id) initWithController:(SproutedAVIController*)controller
{
	if ( self = [super initWithController:controller] )
	{ 
		// movie path information
		NSString *dateTime = [[NSDate date] descriptionWithCalendarFormat:@"%H%M%S" 
				timeZone:nil 
				locale:nil];
				
		NSString *tempDir = NSTemporaryDirectory();
		if ( tempDir == nil ) tempDir = [NSString stringWithString:@"/tmp"];
		
		_moviePath = [[NSString alloc] initWithString:[tempDir stringByAppendingPathComponent:
				[NSString stringWithFormat:@"%@.mov", dateTime]]];
		
		// default encoding and frame rate
		[self setEncodingOption:kEncodingOptionH264];
		[self setPreviewFrameRate:24.0];
		
		[NSBundle loadNibNamed:@"VideoRecorder" owner:self];
		[mMeteringView setNumChannels:1];
		
		_unsavedRecording = NO;
	}
	
	return self;
}

- (void) dealloc 
{			
	if ( mUpdateMeterTimer ) {
		[mUpdateMeterTimer invalidate];
		[mUpdateMeterTimer release], mUpdateMeterTimer = nil;
	}
	
	if ( updatePlaybackLocTimer ) {
		[updatePlaybackLocTimer invalidate];
		[updatePlaybackLocTimer release], updatePlaybackLocTimer = nil;
	}
	
	if ( idleTimer ) {
		[idleTimer invalidate];
		[idleTimer release], idleTimer = nil;
	}
	
	[_moviePath release], _moviePath = nil;
	
	if ( captureData != NULL )
		free((Ptr)captureData), captureData = NULL;
	
	QTMLDestroyMutex(mMutex);
	
	// top level nib objects
	[playbackHolder release], playbackHolder = nil;
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[super dealloc];
}

#pragma mark -

- (BOOL) recorderShouldClose:(NSNotification*)aNotification error:(NSError**)anError
{
	BOOL shouldClose = YES;
	
	if ( captureData->recording )
	{
		shouldClose = NO;
		*anError = [self stillRecordingError];
	}
	else if ( _unsavedRecording == YES && [self warnsWhenUnsavedChanges] )
	{
		shouldClose = NO;
		*anError = [self unsavedChangesError];
	}
	
	return shouldClose;
}

- (BOOL) recorderWillLoad:(NSNotification*)aNotification
{
	// runtime security check prevents subclassing
	if ( ![self isMemberOfClass:[SproutedVideoRecorder class]] )
		return NO;
	
	OSErr err = noErr;
		
	// initialize the qt toolbox
	EnterMovies();
	
	// set up a mutex for multithreaded protection
	mMutex = QTMLCreateMutex();
	
	// ready our data structure
	captureData = (PDCaptureRecordPtr)calloc(sizeof(PDCaptureRecord), 1);
	//err = MemError(); // -109 nil master pointer on Leopard after changing formats <- why was I calling MemError at all?
	if ( /*err ||*/ NULL == captureData ) 
	{
		NSLog(@"%@ %s - unable to allocate memory for capture data, exiting recorder with MemError %i", [self className], _cmd, err);
		
		[self setError:[self videoCaptureError]];
		return NO;
	}
	
	// Make a Sequence Grabber
	captureData->seqGrab = OpenDefaultComponent(SeqGrabComponentType, 0);
	if (captureData->seqGrab != NULL) 
	{ 
		// initialize the default sequence grabber component
		err = SGInitialize(captureData->seqGrab);

		if (err == noErr) 
		{
			// set its graphics world to the specified window
			err = SGSetGWorld(captureData->seqGrab, 
					(CGrafPtr)[[[self view] window] windowRef], 
					NULL);
					
			if ( err )
				NSLog(@"%@ %s - Unable to set g world on sequence grabber", [self className], _cmd);
		}
		else
			NSLog(@"%@ %s - Unable to initialize sequence grabber", [self className], _cmd);
		
		if (err == noErr) 
		{
			err = SGSetDataRef(captureData->seqGrab, 
					0, 
					0, 
					seqGrabDontMakeMovie);
			
			if ( err )
				NSLog(@"%@ %s - nable to set data ref on sequence grabber", [self className], _cmd);
		}
	}

	// clean up on failure
	if (err && (captureData->seqGrab != NULL)) 
	{
		CloseComponent(captureData->seqGrab);
		captureData->seqGrab = NULL;
		
		[self setError:[self videoCaptureError]];
		return NO;
	}
	else
	{
	
		// add the audio/video tracks and make sure they are available
		// the check immediately follows
		
		[self _addVideoTrack];
		[self _addAudioTrack];

		if ( !captureData->audioChan || !captureData->videoChan ) 
		{
			[self setError:[self videoCaptureError]];		
			return NO;
		}
		else
		{
			// preview quality and other variables - you may set the preview quality if you wish
			// although I am admittedly not sure if it has any effect
			
			_mPreviewQuality = codecNormalQuality;
			_previewFrameRate = 0.0;
			_recordingStart = 0.0;
			captureData->recording = NO;
			_prepped = NO;
			_playingMovie = NO;
			
			_inserted = NO;
			_alreadyPrepared = NO;
			_preppedForPlaying = NO;
			
			return YES;
		}
	}
}

- (BOOL) recorderDidLoad:(NSNotification*)aNotification
{
	int videoCodec = [[NSUserDefaults standardUserDefaults] integerForKey:@"DefaultVideoCodec"];
	[self setEncodingOption:videoCodec];
	
	BOOL success = [self prepareForRecording];
	if ( success )
	{
		[insertButton setEnabled:NO];
	}
	else
	{
		[self setError:[self videoCaptureError]];
	}
	
	return success;
}

- (BOOL) recorderWillClose:(NSNotification*)aNotification
{
	if ( captureData->recording )
	{
		[self stop:nil];
	}
	
	if ( !_preppedForPlaying )
	{
		[self takedownRecording];
	}
	else
	{
		if ( updatePlaybackLocTimer ) 
		{
			[updatePlaybackLocTimer invalidate];
			[updatePlaybackLocTimer release], updatePlaybackLocTimer = nil;
		}
	
		[player pause:self];
		[player setMovie:nil];
	}
		
	return YES;
}


#pragma mark -

- (BOOL) prepareForRecording 
{
	// this method must be called before recording begins
	// call it immediately after you have initialized an instance of SproutedVideoRecorder
	
	OSErr err;
	
	// go no further if any recording device is unavailable
	if ( !captureData->audioChan || !captureData->videoChan )
		return NO;
	
	if ( _alreadyPrepared ) 
	{
		// already good to go, reset the interface for recording
		NSBundle *myBundle = [NSBundle bundleWithIdentifier:@"com.sprouted.avi"];
		
		[mRecordPauseButton setAction:@selector(recordPause:)];
		[mRecordPauseButton setState:NSOffState];
		
		[mRecordPauseButton setImage:[[[NSImage alloc] initWithContentsOfFile:[myBundle pathForImageResource:@"beginrecording.png"]] autorelease]];
		[mRecordPauseButton setAlternateImage:[[[NSImage alloc] initWithContentsOfFile:[myBundle pathForImageResource:@"stoprecording.png"]] autorelease]];
		
		// add the preview view
		if ( ![previewPlaceholder window] ) 
		{
			[previewPlaceholder retain];
			[previewPlaceholder setFrame:[player frame]];
			[previewPlaceholder removeFromSuperviewWithoutNeedingDisplay];
			
			[[self view] replaceSubview:player with:previewPlaceholder];
			[previewPlaceholder release];
		}

		// begin the sequence grabber		
		OSStatus err = SGStartRecord(captureData->seqGrab);
		if ( err ) {
			NSLog(@"%@ %s - Video recorded already prepped but unable to start recording", [self className], _cmd);
			goto bail;
		}
		else
			return YES;
	}
	
	// set up the capture data structure and add the callback
	err = [self _initDataAndProc];
	if ( err ) {
		NSLog(@"%@ %s - Unable to init data and proc (%d)", [self className], _cmd, err);
		goto bail;
	}
	
	// prepare the sequence grabber for recording and begin requesting data
	err = SGPrepare(captureData->seqGrab, false, true);
	if ( err ) {
		NSLog(@"%@ %s - Unable to prepare sequence grabber (%d)", [self className], _cmd, err);
		goto bail;
	}
	
	err = SGStartRecord(captureData->seqGrab);
	if ( err ) {
		NSLog(@"%@ %s - Unable to start recording (%d)", [self className], _cmd, err);
		goto bail;
	}
	
	// set the metering and idle timers
	mUpdateMeterTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:.1] 
			interval:kMeterTimerInterval 
			target:self
			selector:@selector(meterTimerCallback:) 
			userInfo:nil 
			repeats:YES];
		
	idleTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:.1] 
				interval:kEventDurationSecond/60 
				target:self
				selector:@selector(idleTimer:) 
				userInfo:nil 
				repeats:YES];
	
	[[NSRunLoop currentRunLoop] addTimer:mUpdateMeterTimer forMode:NSDefaultRunLoopMode]; // or NSModalPanelRunLoopMode
	[[NSRunLoop currentRunLoop] addTimer:idleTimer forMode:NSDefaultRunLoopMode]; // or NSModalPanelRunLoopMode
	
bail:
	
	if ( err ) {
		[mRecordPauseButton setEnabled:NO];
		return NO;
	}
	else
		return YES;	
}

#pragma mark -

- (OSErr) _initDataAndProc {
	
	OSErr err = [self _prepareCaptureData];
	if ( err != noErr ) 
	{
		NSLog(@"%@ %s - Unable to the prepare required data (%d)", [self className], _cmd, err);
		[mRecordPauseButton setEnabled:NO];
		return err;
	}
	
	err = SGSetDataProc( captureData->seqGrab, 
			NewSGDataUPP(GrabDataProc), 
			(long)captureData );
			
	if ( err != noErr ) 
	{
		NSLog(@"%@ %s - Unable to initalize the data proc (%d)", [self className], _cmd, err);
		[mRecordPauseButton setEnabled:NO];
		return err;
	}
	
	_alreadyPrepared = YES;
	return noErr;
}

- (OSErr) _prepareCaptureData {
	
	// prepares the PDCaptureRecordPtr
	// gives the structure access to the class's instance variables among other things that the dataproc callback requires
	
	OSErr err = noErr;
	
	// set up the movie
	Handle outputMovieDataRef = NULL;
	OSType outputMovieDataRefType = 0;
	CFStringRef outputMovieFullPathString = NULL;
	
	// derive a parent and filename from the complete path
	NSString *completePath = [self moviePath];
	NSString *fileName = [completePath lastPathComponent];
	NSString *parentDirectory = [completePath stringByDeletingLastPathComponent];
	
	FSRef parentFSRef;
	
	captureData->width = 320;
	captureData->height = 240;
	
	captureData->desiredFramesPerSecond = 30;
	captureData->mDesiredPreviewFrameRate = _previewFrameRate;
	captureData->previewQuality = [self previewQuality];
	
	captureData->isGrabbing = false;
	captureData->dropFrame = false;
	
	switch ( [self encodingOption] ) {
	
		// depending on the encoding scheme, modify the codec and average data rate
		
		case kEncodingOptionMPEG4:
			captureData->codecType = kMPEG4VisualCodecType;
			captureData->averageDataRate = 70000;
			break;
		case kEncodingOptionH264:
			captureData->codecType = kH264CodecType;
			captureData->averageDataRate = 35000;
			break;
		default:
			captureData->codecType = kMPEG4VisualCodecType;
			captureData->averageDataRate = 70000;
			break;
	
	}
	
	//static CGRect rect = {10,79,320,240};
	NSRect placeholderRect = [previewPlaceholder frame];
	CGRect rect = {	placeholderRect.origin.x,
					placeholderRect.origin.y,
					placeholderRect.size.width,
					placeholderRect.size.height };
	
	[previewPlaceholder lockFocus];
	CGContextRef graphicsContext = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
	[previewPlaceholder unlockFocus];
	
	if ( !graphicsContext ) {
		err = 873;
		NSLog(@"%@ %s - No graphics context", [self className], _cmd);
		goto bail;
	}
	
	captureData->targetRect = rect;
	captureData->graphicsContext = graphicsContext;
	captureData->colorspace = CGColorSpaceCreateDeviceRGB();
	
	err = FSPathMakeRef((UInt8 *) [parentDirectory UTF8String] , &parentFSRef, NULL);
	if( err ) {
		NSLog(@"%@ %s - FSPathMakeRef() failed (%d)", [self className], _cmd, err );
		goto bail;
	}
	
	err = QTNewDataReferenceFromFSRefCFString( &parentFSRef, 
			(CFStringRef)fileName, 
			0, 
			&outputMovieDataRef, 
			&outputMovieDataRefType );
	
	if( err ) {
		NSLog(@"%@ %s - QTNewDataReferenceFromFSRefCFString() failed (%d)", [self className], _cmd, err );
		goto bail;
	}

	
	// Create a new movie file. 
	// If you're using CreateMovieFile, consider switching to CreateMovieStorage, which is long-file-name aware.
	#warning need a corresponding DeleteMovieStorage? -- there's a dispose handle
	err = CreateMovieStorage( outputMovieDataRef, 
			outputMovieDataRefType, 
			'TVOD', 
			0, 
			createMovieFileDeleteCurFile, 
			&captureData->outputMovieDataHandler, 
			&captureData->outputMovie );
			
	if( err ) {
		NSLog(@"%@ %s - CreateMovieStorage failed (%d)", [self className], _cmd, err);
		goto bail;
	}

bail:

	DisposeHandle( outputMovieDataRef );
	if( outputMovieFullPathString ) CFRelease( outputMovieFullPathString );
 	return err;
}

// internal methods for adding the default video and audio track to the sequence grabber
// do not call these methods yourself

- (BOOL)_addVideoTrack;
{
    OSErr err = noErr;
	Rect bounds = {0,0,320,240};
	
    err = SGNewChannel(captureData->seqGrab, VideoMediaType, &captureData->videoChan);
	if ( err != noErr ) {
		NSLog(@"%@ %s - Unable to create new video channel (%d)", [self className], _cmd, err);
		goto bail;
	}
 
	err = SGSetChannelBounds(captureData->videoChan, &bounds);
	if ( err != noErr ) {
		NSLog(@"%@ %s - Unable to set video channel bounds (%d)", [self className], _cmd, err);
		goto bail;
	}
	
	err = SGSetChannelUsage(captureData->videoChan, seqGrabRecord);
	if ( err != noErr ) {
		NSLog(@"%@ %s - Unable to set video channel usage to record (%d)", [self className], _cmd, err);
		goto bail;
	}
		
bail:
	
	if ( err == noErr ) return YES;
	else {
		SGDisposeChannel(captureData->seqGrab, captureData->videoChan);
		captureData->videoChan = NULL;
		return NO;
	}
}


- (BOOL)_addAudioTrack;
{
	OSErr err = noErr;
	BOOL recordMetersWereEnabled, outputMetersWereEnabled, doEnable = YES;
	
    NSString * prevDevice = nil;
	
	AudioStreamBasicDescription oldDescription = { 0 };
	AudioStreamBasicDescription asbd = { 0 };
	
	err = SGNewChannel(captureData->seqGrab, 
			SGAudioMediaType, 
			&captureData->audioChan);
			
	if ( err != noErr ) {
		NSLog(@"%@ %s - Unable to create sequence grabber audio channel (%d)", [self className], _cmd, err);
		goto bail;
	}
	
   	// Want to perform custom set-up on the audi channel?  Do it here.
	err = SGSetChannelUsage(captureData->audioChan, seqGrabRecord | seqGrabPreview);
	if ( err != noErr ) {
		NSLog(@"%@ %s - Unable to set audio channel usage (%d)", [self className], _cmd, err);
		goto bail;
	}

	// instead of just setting the master gain of the preview device very low,
	// first find out if there are any other audi channels using this
	// preview device.  If there are, retain their current volume
	
	// make sure the audio channel is encoding aac audio 128k same number of channels
	err = QTGetComponentProperty(captureData->audioChan, 
			kQTPropertyClass_SGAudio, 
			kQTSGAudioPropertyID_StreamFormat, 
			sizeof(AudioStreamBasicDescription), 
			&oldDescription, 
			NULL);
	
	if ( err != noErr ) {
		NSLog(@"%@ %s - Unable to get audio stream description (%d)", [self className], _cmd, err);
	}
			
	// set a low preview value to avoid feedback
	static const Float32 masterVolume = 0.05;
	err = QTSetComponentProperty(captureData->audioChan, 
			kQTPropertyClass_SGAudioPreviewDevice, 
			kQTSGAudioPropertyID_MasterGain, 
			sizeof(Float32), 
			&masterVolume);
	
	if ( err != noErr ) {
		NSLog(@"%@ %s - Unable to set the master gain on the preview device (%d)", [self className], _cmd, err);
	}
	
	// enable level metering
	err = QTGetComponentProperty(captureData->audioChan, 
			kQTPropertyClass_SGAudioRecordDevice, 
			kQTSGAudioPropertyID_LevelMetersEnabled, 
			sizeof(recordMetersWereEnabled), 
			&recordMetersWereEnabled, NULL);

	if ( err )
		NSLog(@"%@ %s - Unable to get metering property on the hardware side (%d)", [self className], _cmd, err);
	
	if (recordMetersWereEnabled != doEnable)
	{
		err = QTSetComponentProperty(captureData->audioChan, 
				kQTPropertyClass_SGAudioRecordDevice, 
				kQTSGAudioPropertyID_LevelMetersEnabled, 
				sizeof(doEnable), 
				&doEnable);
		
		if ( err )
			NSLog(@"%@ %s - Unable to enable metering on the hardware side (%d)", [self className], _cmd, err);
	}
	
	// enable output metering as well
	err = QTGetComponentProperty(captureData->audioChan, 
			kQTPropertyClass_SGAudio, 
			kQTSGAudioPropertyID_LevelMetersEnabled, 
			sizeof(outputMetersWereEnabled), 
			&outputMetersWereEnabled, 
			NULL);
	
	if ( err )
		NSLog(@"%@ %s - Unable to get metering property on the software side (%d)", [self className], _cmd, err);
	
	if (outputMetersWereEnabled != doEnable)
	{
		err = QTSetComponentProperty(captureData->audioChan, 
				kQTPropertyClass_SGAudio, 
				kQTSGAudioPropertyID_LevelMetersEnabled, 
				sizeof(doEnable), 
				&doEnable);
		
		if ( err )
			NSLog(@"%@ %s - Unable to enable metering on the software side (%d)", [self className], _cmd, err);
	}
	
	// set the audio format
	asbd.mFormatID = kAudioFormatMPEG4AAC;
	asbd.mSampleRate = 48000.;
	asbd.mChannelsPerFrame = oldDescription.mChannelsPerFrame;
	
	err = QTSetComponentProperty(captureData->audioChan, 
			kQTPropertyClass_SGAudio, 
			kQTSGAudioPropertyID_StreamFormat, 
			sizeof(AudioStreamBasicDescription), 
			&asbd);
	
	if ( err != noErr ) {
		NSLog(@"%@ %s - Unable to set audio stream description to aac 128k (%d)", [self className], _cmd, err);
	}

	// the channel number - we are the first (and assuming only) audio channel
	mChannelNumber = 0;	
	    
bail:
	
    if ( prevDevice) [prevDevice release];
	
	if ( err == noErr ) return YES;
	else {
		SGDisposeChannel(captureData->seqGrab, captureData->audioChan);
		return NO;
	}
}

- (OSErr) finishOutputMovie
{
	OSStatus err = noErr;
	Track videoTrack = NULL;
	
	//ICMCompressionSessionCompleteFrames( captureData->compressionSession, true, 0, 0 );
	
	if( captureData->didBeginVideoMediaEdits ) {
		// End the media sample-adding session.
		err = EndMediaEdits( captureData->videoMedia );
		if( err ) {
			NSLog(@"%@ %s - EndMediaEdits() failed (%d)", [self className], _cmd, err );
			goto bail;
		}
	}
	
	
	// Make sure things are extra neat.
	ExtendMediaDecodeDurationToDisplayEndTime( captureData->videoMedia, NULL );
	
	// Insert the stuff we added into the track, at the end.
	videoTrack = GetMediaTrack( captureData->videoMedia );
	err = InsertMediaIntoTrack( videoTrack, 
			GetTrackDuration(videoTrack), 
			0, GetMediaDisplayDuration( captureData->videoMedia ), // NOTE: use this instead of GetMediaDuration
			fixed1 );
			
	if( err ) {
		NSLog(@"%@ %s - InsertMediaIntoTrack() failed (%d)", [self className], _cmd, err );
		goto bail;
	}
	
	if ( captureData->didBeginSoundMediaEdits )
	{
		err = EndMediaEdits( captureData->soundMedia );
		if( err ) {
			NSLog(@"%@ %s - EndMediaEdits(soundMedia) failed (%d)", [self className], _cmd, err );
			goto bail;
		}
	}
	
    {
        Track soundTrack = GetMediaTrack( captureData->soundMedia );
        TimeValue soundTrackDur, videoTrackDur;
        err = InsertMediaIntoTrack( soundTrack, 0, 0, GetMediaDuration( captureData->soundMedia ), fixed1 );
        if ( err ) {
            NSLog(@"%@ %s - InsertMediaIntoTrack(soundTrack) failed (%d)", [self className], _cmd, err );
            goto bail;
        }
        
        // trim the sound track to the duration of the video track 
        // (no one likes white frames at the end of their movies)
        soundTrackDur = GetTrackDuration(soundTrack);
	    videoTrackDur = GetTrackDuration(videoTrack);
        if (soundTrackDur > videoTrackDur)
        {
			//NSLog(@"sound track ran long, soundTrackDur = %ld, videoTrackDur = %ld", soundTrackDur, videoTrackDur );
            DeleteTrackSegment(soundTrack, videoTrackDur, soundTrackDur - videoTrackDur);
        }
	}
	
	// Write the movie header to the file.
	err = AddMovieToStorage( captureData->outputMovie, captureData->outputMovieDataHandler );
	if( err ) {
		NSLog(@"%@ %s - AddMovieToStorage() failed (%d)", [self className], _cmd, err );
		goto bail;
	}
	
	CloseMovieStorage( captureData->outputMovieDataHandler );
	captureData->outputMovieDataHandler = 0;
	
	DisposeTrackMedia(captureData->videoMedia);
	DisposeTrackMedia(captureData->soundMedia);
	
	DisposeMovie( captureData->outputMovie );
	
bail:
	return err;
}

#pragma mark -


- (int) encodingOption 
{ 
	return _encodingOption; 
}

- (void) setEncodingOption:(int)option 
{
	_encodingOption = option;
}

- (void)setPreviewQuality:(CodecQ)quality
{
	_mPreviewQuality = quality;
}

- (CodecQ)previewQuality
{
	return _mPreviewQuality;
}

- (float) previewFrameRate 
{ 
	return _previewFrameRate; 
}

- (void) setPreviewFrameRate:(float)rate 
{
	_previewFrameRate = rate;
}

- (NSString*) moviePath 
{ 
	return _moviePath;
}

- (void) setMoviePath:(NSString*)path 
{
	if ( _moviePath != path ) 
	{
		[_moviePath release];
		_moviePath = [path copyWithZone:[self zone]];
	}
}

#pragma mark -

- (BOOL) inserted 
{ 
	return _inserted;
}

#pragma mark -

- (IBAction)setChannelGain:(id)sender
{
	// set the hardware gain for each channel
	
	OSErr err;
	Float32 myValue = [sender floatValue];
	UInt32 size, flags;
	
	BOOL useAudioDevice = NO;
	BOOL useMasterGain = NO;
	
	// this is setting the master gain on the harware side
	// if that does not work, set it on the system side
	
	// get the number of channels by querying the size variable
	// kQTPropertyClass_SGAudioPreviewDevice
	
beginning:
	
	err = QTGetComponentPropertyInfo(captureData->audioChan, 
			kQTPropertyClass_SGAudioRecordDevice,
			kQTSGAudioPropertyID_PerChannelGain, 
			NULL, 
			&size, 
			&flags);
	
	if ( err == noErr && size && (flags & kComponentPropertyFlagCanSetNow) ) {
	
		Float32 * chanGains = (Float32*)malloc(size * sizeof(Float32));
		UInt32 numChannelGains = size/sizeof(Float32);
		
		int i;
		for ( i = 0; i < numChannelGains; i++ )
			chanGains[i] = myValue;

		err = QTSetComponentProperty(captureData->audioChan,
				kQTPropertyClass_SGAudioRecordDevice,
				kQTSGAudioPropertyID_PerChannelGain,
				size,
				chanGains);
	
		if ( err != noErr ) 
		{
			useAudioDevice = YES;
			goto hadErr;
		}
		
		if (chanGains) free(chanGains);
	}
	else 
	{
		useAudioDevice = YES;
		goto hadErr;
	}
	
hadErr:

	if ( useAudioDevice ) 
	{
		// didn't work, so try to set hardware gain
		err = QTGetComponentPropertyInfo(captureData->audioChan, 
				kQTPropertyClass_SGAudio, 
				kQTSGAudioPropertyID_PerChannelGain, 
				NULL,
				&size, 
				&flags);
		
		Float32 * chanGains = (Float32*)malloc(size * sizeof(Float32));
		UInt32 numChannelGains = size/sizeof(Float32);
		
		int i;
		for ( i = 0; i < numChannelGains; i++ )
			chanGains[i] = myValue;
		
		if ( err == noErr && size && (flags & kComponentPropertyFlagCanSetNow) ) 
		{
			err = QTSetComponentProperty(captureData->audioChan,
					kQTPropertyClass_SGAudio,
					kQTSGAudioPropertyID_PerChannelGain,
					size,
					chanGains);
			
			if ( err ) 
			{
				useMasterGain = YES;
				goto hadFurtherErr;
			}
		}
		else 
		{
			useMasterGain = YES;
			goto hadFurtherErr;
		}
		
		if (chanGains) free(chanGains);
		
	}
	
hadFurtherErr:

	if ( useMasterGain ) 
	{
		err = QTSetComponentProperty(captureData->audioChan,
				kQTPropertyClass_SGAudio,
				kQTSGAudioPropertyID_MasterGain,
				sizeof(myValue),
				&myValue);
		
		if ( err != noErr ) 
			NSLog(@"%@ %s - Last resort, tried to set master gain, didn't work (%d)", [self className], _cmd, err);
	}
	
ending:

	// update the volume image display
	[volumeImage setImage:[self volumeImage:myValue minimumVolume:[sender minValue]]];
}

- (void) meterTimerCallback:(id)object 
{	
	if ( captureData->recording ) 
	{
		// update the seconds
		int totalSeconds = (int)(GetCurrentEventTime() - _recordingStart);
		
		int hours = (int)(floor(totalSeconds / 3600));
		int hoursLeftover = (int)(floor(totalSeconds % 3600));
		
		int minutes = (int)(floor(hoursLeftover / 60 ));
		int seconds = (int)floor(hoursLeftover) % 60;
		
		[timeField setStringValue:[NSString stringWithFormat:@"%i%i:%i%i:%i%i",
				hours/10,
				hours%10,
				minutes/10,
				minutes%10,
				seconds/10,
				seconds%10]];
	
		// update the size
		int totalSize = captureData->length / 1024; // = kBytes
		int mbs = totalSize / 1000;
		int kbs = totalSize % 1000 / 100;
		
		[sizeField setStringValue:[NSString stringWithFormat:@"%i.%iMB", mbs, kbs]];
	}
	
	[self updateChannelLevel];
}

- (void)updateChannelLevel
{
    OSErr err;
	Float32 amps[2] = { -FLT_MAX, -FLT_MAX };
    
	if ( !QTMLTryGrabMutex(mMutex) )
		return;
	
    QTMLGrabMutex(mMutex);
	
	if (mLevelsArray == NULL)
	{    
		UInt32 size;
		
		err = QTGetComponentPropertyInfo( captureData->audioChan, 
				kQTPropertyClass_SGAudioRecordDevice, 
				kQTSGAudioPropertyID_ChannelMap, 
				NULL, 
				&size, 
				NULL );
		
		if (size > 0)
		{
			SInt32 * map = (SInt32 *)malloc(size);
			
			err = QTGetComponentProperty(captureData->audioChan, 
					kQTPropertyClass_SGAudioRecordDevice, 
					kQTSGAudioPropertyID_ChannelMap, 
					size, 
					map, 
					&size);
			
			int i;
			for (i = 0; i < size/sizeof(SInt32); i++)
			{
				if (mChannelNumber == map[i])
				{
					mMyIndex = i;
					mLevelsArraySize = size; // SInt32 and Float32 are the same size
					mLevelsArray = (Float32*)malloc(mLevelsArraySize); 
					break;
				}
			}
			free(map);
		}
	}
	
	if (mLevelsArray) // paranoia
	{
		// get the avg power level
		err = QTGetComponentProperty(captureData->audioChan, 
				kQTPropertyClass_SGAudioRecordDevice, 
				kQTSGAudioPropertyID_AveragePowerLevels,
				mLevelsArraySize, 
				mLevelsArray, 
				NULL);
				
		if ( err == noErr )
			amps[0] = mLevelsArray[mMyIndex];
		
		// get the peak hold level
		err = QTGetComponentProperty(captureData->audioChan, 
				kQTPropertyClass_SGAudioRecordDevice, 
				kQTSGAudioPropertyID_PeakHoldLevels,
				mLevelsArraySize, 
				mLevelsArray, 
				NULL);
				
		if ( err = noErr )
			amps[1] = mLevelsArray[mMyIndex];
	}
    
    QTMLReturnMutex(mMutex);
    [mMeteringView updateMeters:amps];
}

#pragma mark -

- (IBAction)recordPause:(id)sender
{
	if ( captureData->recording )
	{
		[self stop:sender];
		
		// update the view and release no longer needed information
		[self prepareForPlaying:self];
		
		[mRecordPauseButton accessibilitySetOverrideValue:NSLocalizedStringFromTableInBundle(
					@"play description",
					@"Localizable",
					[NSBundle bundleWithIdentifier:@"com.sprouted.avi"],
					nil)
				forAttribute:NSAccessibilityDescriptionAttribute];
	}
	else 
	{
		captureData->length = 0;
		captureData->recording = YES;
		_recordingStart = GetCurrentEventTime();
		
		[mRecordPauseButton accessibilitySetOverrideValue:NSLocalizedStringFromTableInBundle(
					@"stop description",
					@"Localizable",
					[NSBundle bundleWithIdentifier:@"com.sprouted.avi"],
					nil)
				forAttribute:NSAccessibilityDescriptionAttribute];
	}
}

- (IBAction)stop:(id)sender
{
	[self stopRecording:sender];
}

- (IBAction) stopRecording:(id)sender
{
	if ( captureData->recording )
	{
		OSStatus err = SGStop(captureData->seqGrab);
		captureData->recording = NO;
        
		if (err == noErr)
        {
		   // close the movie file and write it out
		   [self finishOutputMovie];
		   
		   _unsavedRecording = YES;
        }
        else 
		{
           [[NSAlert unableToStopVideoRecording] runModal];
        }
	}
	else
	{
		NSBeep();
	}
}

#pragma mark -

- (BOOL) takedownRecording 
{
	// completely stop the sequence grabber and remove the data proc
	
	if ( mUpdateMeterTimer ) 
	{
		[mUpdateMeterTimer invalidate];
		[mUpdateMeterTimer release], mUpdateMeterTimer = nil;
	}
	
	if ( idleTimer ) 
	{
		[idleTimer invalidate];
		[idleTimer release], idleTimer = nil;
	}
	
	// no longer previewing or recording
	SGSetChannelUsage(captureData->audioChan,0);
	SGSetChannelUsage(captureData->videoChan,0);
	
	// stop the sequence grabber and remove the callback
	SGStop(captureData->seqGrab);
	SGSetDataProc(captureData->seqGrab,NULL,0);
	
	// close access to the sequence grabber components
	SGDisposeChannel(captureData->seqGrab, captureData->audioChan);
	SGDisposeChannel(captureData->seqGrab, captureData->videoChan);
	CloseComponent(captureData->seqGrab);
	
	CGColorSpaceRelease(captureData->colorspace);
	
	// release the captureData memory
	ICMDecompressionSessionRelease( captureData->decompressionSession );
	ICMCompressionSessionRelease( captureData->compressionSession );
	DisposeHandle((Handle)captureData->audioDescH);
	
	return YES;
}

- (IBAction) prepareForPlaying:(id)sender 
{	
	[self takedownRecording];
	
	// switch the preview view out and replace it with the quicktime view
	if ( [QTMovie canInitWithFile:[self moviePath]] ) 
	{
		// prepare the movie
		QTMovie *movie = [[QTMovie alloc] initWithFile:[self moviePath] error:nil];
		[player setMovie:movie];
		
		// set the playback volume and playback volume slider
		[volumeSlider setFloatValue:0.9];
		[volumeSlider setAction:@selector(changePlaybackVolume:)];
		[self changePlaybackVolume:volumeSlider];
		
		// set playback duration values
		double movieLength = [movie duration].timeValue;
		[playbackLocSlider setMaxValue:movieLength];
		[playbackLocSlider setFloatValue:0.0];
		
		// register a notification to grab the end of the movie
		[[NSNotificationCenter defaultCenter] 
				addObserver:self 
				selector:@selector(movieEnded:) 
				name:QTMovieDidEndNotification 
				object:movie];
		
		// prepare a timer to handle an update of the playback
		updatePlaybackLocTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:.1] 
				interval:kPlaybacklockTimerInterval 
				target:self
				selector:@selector(playlockCallback:) 
				userInfo:nil 
				repeats:YES];
		
		[[NSRunLoop currentRunLoop] addTimer:updatePlaybackLocTimer forMode:NSDefaultRunLoopMode]; // or NSModalPanelRunLoopMode
		
		// clean up
		[movie release];
	}
	else 
	{
		[[NSAlert unreadableVideoFile] runModal];
		
		[mRecordPauseButton setEnabled:NO];
		[fastforward setEnabled:NO];
		[rewind setEnabled:NO];
	}
	
	// set the record button to play/pause mode
	NSBundle *myBundle = [NSBundle bundleWithIdentifier:@"com.sprouted.avi"];
	
	[mRecordPauseButton setImage:[[[NSImage alloc] initWithContentsOfFile:[myBundle pathForImageResource:@"playrecording.png"]] autorelease]];
	[mRecordPauseButton setAlternateImage:[[[NSImage alloc] initWithContentsOfFile:[myBundle pathForImageResource:@"pauserecording.png"]] autorelease]];
	[mRecordPauseButton setAction:@selector(playPause:)];
	
	// make the playback slider visible and hide the metering view
	NSPoint playlockFrame = [mMeteringView frame].origin;
	
	[playbackLocSlider retain];
	[playbackLocSlider removeFromSuperviewWithoutNeedingDisplay];
	[playbackLocSlider setFrameOrigin:playlockFrame];
	
	// get the playback slider ready to fade in
	[playbackLocSlider setHidden:YES];
	[[self view] addSubview:playbackLocSlider];
	
	NSViewAnimation *theAnim;
						
	NSDictionary *theDict = [[[NSDictionary alloc] initWithObjectsAndKeys:
			fastforward, NSViewAnimationTargetKey, 
			NSViewAnimationFadeInEffect, NSViewAnimationEffectKey, nil] autorelease];
	
	NSDictionary *otherDict = [[[NSDictionary alloc] initWithObjectsAndKeys:
			rewind, NSViewAnimationTargetKey, 
			NSViewAnimationFadeInEffect, NSViewAnimationEffectKey, nil] autorelease];
	
	NSDictionary *playbackDict = [[[NSDictionary alloc] initWithObjectsAndKeys:
			playbackLocSlider, NSViewAnimationTargetKey, 
			NSViewAnimationFadeInEffect, NSViewAnimationEffectKey, nil] autorelease];
	
	NSDictionary *meteringDict = [[[NSDictionary alloc] initWithObjectsAndKeys:
			mMeteringView, NSViewAnimationTargetKey, 
			NSViewAnimationFadeOutEffect, NSViewAnimationEffectKey, nil] autorelease];

	theAnim = [[NSViewAnimation alloc] initWithViewAnimations:[NSArray arrayWithObjects:theDict, otherDict, playbackDict, meteringDict, /*insertDict,*/ nil]];
	[theAnim startAnimation];
	
	// remove the metering view once the animation is complete
	[mMeteringView removeFromSuperview];
	[insertButton setEnabled:YES];
	
	// clean up
	[theAnim release];
	[playbackLocSlider release];

	// finally add the main new subview
	[player retain];
	[player setFrame:[previewPlaceholder frame]];
	[player removeFromSuperviewWithoutNeedingDisplay];
	
	[[self view] replaceSubview:previewPlaceholder with:player];
	[player release];
	
	// probably release a slew of no longer needed memory
	_preppedForPlaying = YES;
}

- (IBAction)playPause:(id)sender 
{
	if ( !_playingMovie ) 
	{
		[mRecordPauseButton accessibilitySetOverrideValue:NSLocalizedStringFromTableInBundle(
					@"stop description",
					@"Localizable",
					[NSBundle bundleWithIdentifier:@"com.sprouted.avi"],
					nil)
				forAttribute:NSAccessibilityDescriptionAttribute];
		[player play:sender];
	}
	else 
	{
		[mRecordPauseButton accessibilitySetOverrideValue:NSLocalizedStringFromTableInBundle(
					@"play description",
					@"Localizable",
					[NSBundle bundleWithIdentifier:@"com.sprouted.avi"],
					nil) 
				forAttribute:NSAccessibilityDescriptionAttribute];
		[player pause:sender];
	}
	
	_playingMovie = !_playingMovie;
}

- (IBAction) changePlaybackVolume:(id)sender 
{	
	[[player movie] setVolume:[sender floatValue]];
	[volumeImage setImage:[self volumeImage:[sender floatValue] minimumVolume:[sender minValue]]];
}

- (NSImage*) volumeImage:(float)volume minimumVolume:(float)minimum
{
	NSString *imageFilename = nil;
	NSBundle *myBundle = [NSBundle bundleWithIdentifier:@"com.sprouted.avi"];
	
	if ( volume == minimum )
		imageFilename = [myBundle pathForImageResource:@"VolumeMeterMute.tif"];
	else if ( volume > 0 && volume < 0.33 )
		imageFilename = [myBundle pathForImageResource:@"VolumeMeter1.tif"];
	else if ( volume >= 0.33 && volume < 0.66 )
		imageFilename = [myBundle pathForImageResource:@"VolumeMeter2.tif"];
	else
		imageFilename = [myBundle pathForImageResource:@"VolumeMeter3.tif"];
		
	return [[[NSImage alloc] initWithContentsOfFile:imageFilename] autorelease];
}

- (IBAction) changePlaybackLocation:(id)sender 
{	
	// changes the playback position in response to slider movement
	
	double location = [sender doubleValue];
	double timeScale = [[player movie] currentTime].timeScale;
	
	QTTime locationAsTime = { (long long )location, (long)timeScale, 0 };
	[[player movie] setCurrentTime:locationAsTime];
}

- (void) playlockCallback:(id)object 
{
	// called to update the playback position on the playlock slider
	
	NSString *timeString;
	QTTime current = [[player movie] currentTime];
	
	[playbackLocSlider setDoubleValue:current.timeValue];
	
	timeString = QTStringFromTime(current);
	[timeField setStringValue:[timeString substringWithRange:NSMakeRange(2, 8)]];	
}

- (IBAction) fastForward:(id)sender 
{
	[player stepForward:self];
	[mRecordPauseButton setState:NSOffState];
	[self playlockCallback:self];
	_playingMovie = NO;
}

- (IBAction) rewind:(id)sender 
{
	[player stepBackward:self];
	[mRecordPauseButton setState:NSOffState];
	[self playlockCallback:self];
	_playingMovie = NO;
}

- (void) movieEnded:(NSNotification*)aNotification 
{
	// a callpack when the movie ends
	// reset the play button and playing status
	
	_playingMovie = NO;
	[mRecordPauseButton setState:NSOffState];
}


#pragma mark -

- (void)idleTimer:(NSTimer*)timer
{
	SGIdle(captureData->seqGrab);
}

#pragma mark -

- (IBAction) insertEntry:(id)sender 
{
	[self saveRecording:sender];
}

- (IBAction) saveRecording:(id)sender
{
	_inserted = YES;
	
	// insert the recording
	id theTarget = [NSApp targetForAction:@selector(sproutedVideoRecorder:insertRecording:title:) to:nil from:self];
	if ( theTarget != nil ) 
	{
		_unsavedRecording = NO; // doesn't (can't) take into account a user cancellation
		[theTarget sproutedVideoRecorder:self insertRecording:[self moviePath] title:nil];
	}
	else
	{
		NSBeep();
		NSLog(@"%@ %s - invalid target", [self className], _cmd);
	}
}

#pragma mark -

- (NSString*) videoCaptureError
{
	NSString *errorMessage = NSLocalizedStringFromTableInBundle(
			@"no video capture msg", 
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"");
	NSString *errorInfo = NSLocalizedStringFromTableInBundle(
			@"no video capture info", 
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"");
			
	NSString *myError = [NSString stringWithFormat:@"%@\n\n%@", errorMessage, errorInfo];
	return myError;
}

@end
