//
//  SproutedLeopardVideoRecorder.m
//  Sprouted AVI
//
//  Created by Philip Dow on 4/30/08.
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


#import <SproutedAVI/SproutedLeopardVideoRecorder.h>
#import <SproutedAVI/SproutedAVIAlerts.h>

#define kEncodingOptionH264		0
#define kEncodingOptionMPEG4	1

#define kMeterTimerInterval			1.0/15
#define kPlaybacklockTimerInterval	1.0/30

@implementation SproutedLeopardVideoRecorder

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
		
		mMoviePath = [[NSString alloc] initWithString:[tempDir stringByAppendingPathComponent:
				[NSString stringWithFormat:@"%@.mov", dateTime]]];
		
		mUnsavedRecording = NO;
		[NSBundle loadNibNamed:@"VideoRecorder_105" owner:self];
	}

	return self;
}

- (void) dealloc
{
	[mMoviePath release], mMoviePath = nil;
	[mCaptureSession release], mCaptureSession = nil;
	[mCaptureMovieFileOutput release], mCaptureMovieFileOutput = nil;
	[mCaptureVideoDeviceInput release], mCaptureVideoDeviceInput = nil;
    [mCaptureAudioDeviceInput release], mCaptureAudioDeviceInput = nil;
	
	if (mAudioLevelTimer != nil)
	{
		[mAudioLevelTimer invalidate];
		[mAudioLevelTimer release], mAudioLevelTimer = nil;
	}
	
	if (mUpdatePlaybackLocTimer != nil)
	{
		[mUpdatePlaybackLocTimer invalidate];
		[mUpdatePlaybackLocTimer release], mUpdatePlaybackLocTimer = nil;
	}
	
	// top level nib objects
	[mPlaybackHolder release], mPlaybackHolder = nil;
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[super dealloc];
}

#pragma mark -

- (BOOL) recorderShouldClose:(NSNotification*)aNotification error:(NSError**)anError
{
	BOOL shouldClose = YES;
	
	if ( mRecording )
	{
		shouldClose = NO;
		*anError = [self stillRecordingError];
	}
	else if ( mUnsavedRecording == YES && [self warnsWhenUnsavedChanges] )
	{
		shouldClose = NO;
		*anError = [self unsavedChangesError];
	}
	
	return shouldClose;
}

- (BOOL) recorderWillLoad:(NSNotification*)aNotification
{
	// runtime security check prevents subclassing
	if ( ![self isMemberOfClass:[SproutedLeopardVideoRecorder class]] )
		return NO;
	
	// Create the capture session
	mCaptureSession = [[QTCaptureSession alloc] init];
    
	// Connect inputs and outputs to the session	
	BOOL success = NO;
	NSError *localError;
	
	// Find a video device  
    QTCaptureDevice *videoDevice = [QTCaptureDevice defaultInputDeviceWithMediaType:QTMediaTypeVideo];
    success = [videoDevice open:&localError];
    
	// If a video input device can't be found or opened, try to find and open a muxed input device
	if (!success) 
	{
		videoDevice = [QTCaptureDevice defaultInputDeviceWithMediaType:QTMediaTypeMuxed];
		success = [videoDevice open:&localError];
    }
    
    if (!success) 
	{
        videoDevice = nil;
        [self setError:[self videoCaptureError]];
		goto bail;
    }
	
	if ( videoDevice ) 
	{
		//Add the video device to the session as a device input
		mCaptureVideoDeviceInput = [[QTCaptureDeviceInput alloc] initWithDevice:videoDevice];
		success = [mCaptureSession addInput:mCaptureVideoDeviceInput error:&localError];
		if (!success) 
		{
			// Handle error
			[self setError:[self videoCaptureError]];
			goto bail;
		}
        else
		{
			// If the video device doesn't also supply audio, add an audio device input to the session
			if (![videoDevice hasMediaType:QTMediaTypeSound] && ![videoDevice hasMediaType:QTMediaTypeMuxed]) 
			{
				
				QTCaptureDevice *audioDevice = [QTCaptureDevice defaultInputDeviceWithMediaType:QTMediaTypeSound];
				success = [audioDevice open:&localError];
				
				if (!success) 
				{
					audioDevice = nil;
					[self setError:[self videoCaptureError]];
					goto bail;
				}
				else if (audioDevice) 
				{
					mCaptureAudioDeviceInput = [[QTCaptureDeviceInput alloc] initWithDevice:audioDevice];
					success = [mCaptureSession addInput:mCaptureAudioDeviceInput error:&localError];
					if (!success)
					{
						// Handle error
						[self setError:[self videoCaptureError]];
						goto bail;
					}
				}
			}
			
			// Create the movie file output and add it to the session
			mCaptureMovieFileOutput = [[QTCaptureMovieFileOutput alloc] init];
			success = [mCaptureSession addOutput:mCaptureMovieFileOutput error:&localError];
			if (!success) 
			{
				// Handle error
				[self setError:[self videoCaptureError]];
				goto bail;
			}
			
			[mCaptureMovieFileOutput setDelegate:self];
			
			// Set the compression for the audio/video that is recorded to the hard disk.
			NSEnumerator *connectionEnumerator = [[mCaptureMovieFileOutput connections] objectEnumerator];
			QTCaptureConnection *connection;
			
			NSString *audioCompression = @"QTCompressionOptionsHighQualityAACAudio";
			NSString *videoCompression = ( [[NSUserDefaults standardUserDefaults] 
					integerForKey:@"DefaultVideoCodec"] == kEncodingOptionH264 ?
					@"QTCompressionOptions240SizeH264Video" :
					@"QTCompressionOptions240SizeMPEG4Video" );
			
			// iterate over each output connection for the capture session and specify the desired compression
			while ( (connection = [connectionEnumerator nextObject]) ) 
			{
				NSString *mediaType = [connection mediaType];
				QTCompressionOptions *compressionOptions = nil;
				
				// specify the video and audio compression options
				// (note: a list of other valid compression types can be found in the QTCompressionOptions.h interface file)
				if ([mediaType isEqualToString:QTMediaTypeVideo]) 
				{
					// use H.264: @"QTCompressionOptions240SizeH264Video"
					// or use mpeg: @"QTCompressionOptions240SizeMPEG4Video"
					compressionOptions = [QTCompressionOptions compressionOptionsWithIdentifier:videoCompression];
				
				} 
				else if ([mediaType isEqualToString:QTMediaTypeSound]) 
				{
					// use AAC Audio: @"QTCompressionOptionsHighQualityAACAudio"
					compressionOptions = [QTCompressionOptions compressionOptionsWithIdentifier:audioCompression];
				}
				
				// set the compression options for the movie file output
				[mCaptureMovieFileOutput setCompressionOptions:compressionOptions forConnection:connection];
			}
		}
	}
	
bail:
	
	return success;
}

- (BOOL) recorderDidLoad:(NSNotification*)aNotification
{
	// Associate the capture view in the UI with the session
	[mCaptureView setCaptureSession:mCaptureSession];
	[mCaptureSession startRunning];
	
	mAudioLevelTimer = [[NSTimer scheduledTimerWithTimeInterval:kMeterTimerInterval
			target:self 
			selector:@selector(updateAudioLevels:) 
			userInfo:nil 
			repeats:YES] retain];
	
	return YES;
}

- (BOOL) recorderWillClose:(NSNotification*)aNotification
{
	[self takedownRecording];
	return YES;
}

- (BOOL) recorderDidClose:(NSNotification*)aNotification
{
	return YES;
}

#pragma mark -

- (NSString*) moviePath
{
	return mMoviePath;
}

- (void) setMoviePath:(NSString*)path
{
	if ( mMoviePath != path )
	{
		[mMoviePath release];
		mMoviePath = [path copyWithZone:[self zone]];
	}
}

#pragma mark -

- (IBAction)recordPause:(id)sender
{
	if ( mRecording )
	{
		[self stopRecording:sender];
		[mRecordPauseButton accessibilitySetOverrideValue:NSLocalizedStringFromTableInBundle(
					@"play description",
					@"Localizable",
					[NSBundle bundleWithIdentifier:@"com.sprouted.avi"],
					nil)
				forAttribute:NSAccessibilityDescriptionAttribute];
	}
	else 
	{
		[self startRecording:sender];
		[mRecordPauseButton accessibilitySetOverrideValue:NSLocalizedStringFromTableInBundle(
					@"stop description",
					@"Localizable",
					[NSBundle bundleWithIdentifier:@"com.sprouted.avi"],
					nil)
				forAttribute:NSAccessibilityDescriptionAttribute];
	}
}

- (IBAction) startRecording:(id)sender
{
	mRecording = YES;
	mRecordingStart = GetCurrentEventTime();
	[mCaptureMovieFileOutput recordToOutputFileURL:[NSURL fileURLWithPath:mMoviePath]];
}

- (IBAction) stopRecording:(id)sender
{
	if ( mRecording )
	{
		mRecording = NO;
		mUnsavedRecording = YES;
		[mCaptureMovieFileOutput recordToOutputFileURL:nil];
	}
	else
	{
		NSBeep();
	}
}

- (IBAction)setChannelGain:(id)sender
{
	// no idea if this is even possible
	
	// update the volume image display
	[mVolumeImage setImage:[self volumeImage:[sender floatValue] minimumVolume:[sender minValue]]];
}

#pragma mark -

- (void)captureOutput:(QTCaptureFileOutput *)captureOutput 
		didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL 
		forConnections:(NSArray *)connections 
		dueToError:(NSError *)error
{
	[self prepareForPlaying];
	[self takedownRecording];
}

- (void) takedownRecording
{
	if (mAudioLevelTimer != nil)
	{
		[mAudioLevelTimer invalidate];
		[mAudioLevelTimer release], mAudioLevelTimer = nil;
	}
	
	if ( [mCaptureSession isRunning] )
		[mCaptureSession stopRunning];
		
	if ([[mCaptureVideoDeviceInput device] isOpen])
        [[mCaptureVideoDeviceInput device] close];
    
    if ([[mCaptureAudioDeviceInput device] isOpen])
        [[mCaptureAudioDeviceInput device] close];
}

- (void) prepareForPlaying
{
	// switch the preview view out and replace it with the quicktime view
	if ( [QTMovie canInitWithFile:[self moviePath]] ) 
	{
		// prepare the movie
		QTMovie *movie = [[QTMovie alloc] initWithFile:[self moviePath] error:nil];
		[mPlayer setMovie:movie];
		
		// set the playback volume and playback volume slider
		[mVolumeSlider setFloatValue:0.9];
		[mVolumeSlider setAction:@selector(changePlaybackVolume:)];
		[self changePlaybackVolume:mVolumeSlider];
		
		// set playback duration values
		double movieLength = [movie duration].timeValue;
		[mPlaybackLocSlider setMaxValue:movieLength];
		[mPlaybackLocSlider setFloatValue:0.0];
		
		// register a notification to grab the end of the movie
		[[NSNotificationCenter defaultCenter] 
				addObserver:self 
				selector:@selector(movieEndedCallback:) 
				name:QTMovieDidEndNotification 
				object:movie];
		
		// prepare a timer to handle an update of the playback
		mUpdatePlaybackLocTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:.1] 
				interval:kPlaybacklockTimerInterval 
				target:self
				selector:@selector(playlockCallback:) 
				userInfo:nil 
				repeats:YES];
		
		[[NSRunLoop currentRunLoop] addTimer:mUpdatePlaybackLocTimer forMode:NSDefaultRunLoopMode]; // or NSModalPanelRunLoopMode
		
		// clean up
		[movie release];
	}
	else 
	{
		[[NSAlert unreadableVideoFile] runModal];
		
		[mRecordPauseButton setEnabled:NO];
		[mFastforwardButton setEnabled:NO];
		[mRewindButton setEnabled:NO];
	}
	
	// set the record button to play/pause mode
	NSBundle *myBundle = [NSBundle bundleWithIdentifier:@"com.sprouted.avi"];
	
	[mRecordPauseButton setImage:[[[NSImage alloc] initWithContentsOfFile:[myBundle pathForImageResource:@"playrecording.png"]] autorelease]];
	[mRecordPauseButton setAlternateImage:[[[NSImage alloc] initWithContentsOfFile:[myBundle pathForImageResource:@"pauserecording.png"]] autorelease]];
	[mRecordPauseButton setAction:@selector(playPause:)];
	
	// make the playback slider visible and hide the metering view
	NSPoint playlockFrame = [mAudioLevelMeter frame].origin;
	
	[mPlaybackLocSlider retain];
	[mPlaybackLocSlider removeFromSuperviewWithoutNeedingDisplay];
	[mPlaybackLocSlider setFrameOrigin:playlockFrame];
	
	// get the playback slider ready to fade in
	[mPlaybackLocSlider setHidden:YES];
	[[self view] addSubview:mPlaybackLocSlider];
	
	NSViewAnimation *theAnim;
						
	NSDictionary *theDict = [[[NSDictionary alloc] initWithObjectsAndKeys:
			mFastforwardButton, NSViewAnimationTargetKey, 
			NSViewAnimationFadeInEffect, NSViewAnimationEffectKey, nil] autorelease];
	
	NSDictionary *otherDict = [[[NSDictionary alloc] initWithObjectsAndKeys:
			mRewindButton, NSViewAnimationTargetKey, 
			NSViewAnimationFadeInEffect, NSViewAnimationEffectKey, nil] autorelease];
	
	NSDictionary *playbackDict = [[[NSDictionary alloc] initWithObjectsAndKeys:
			mPlaybackLocSlider, NSViewAnimationTargetKey, 
			NSViewAnimationFadeInEffect, NSViewAnimationEffectKey, nil] autorelease];
	
	NSDictionary *meteringDict = [[[NSDictionary alloc] initWithObjectsAndKeys:
			mAudioLevelMeter, NSViewAnimationTargetKey, 
			NSViewAnimationFadeOutEffect, NSViewAnimationEffectKey, nil] autorelease];

	theAnim = [[NSViewAnimation alloc] initWithViewAnimations:[NSArray arrayWithObjects:theDict, otherDict, playbackDict, meteringDict, /*insertDict,*/ nil]];
	[theAnim startAnimation];
	
	// remove the metering view once the animation is complete
	[mAudioLevelMeter removeFromSuperview];
	[mInsertButton setEnabled:YES];
	
	// clean up
	[theAnim release];
	[mPlaybackLocSlider release];

	// finally add the main new subview
	[mPlayer retain];
	[mPlayer setFrame:[mCaptureView frame]];
	[mPlayer removeFromSuperviewWithoutNeedingDisplay];
	
	[[self view] replaceSubview:mCaptureView with:mPlayer];
	[mPlayer release];
	
	return;
}

#pragma mark -

- (IBAction)playPause:(id)sender 
{
	if ( !mPlayingMovie ) 
	{
		[mPlayer play:sender];
		[mRecordPauseButton accessibilitySetOverrideValue:NSLocalizedStringFromTableInBundle(
					@"stop description",
					@"Localizable",
					[NSBundle bundleWithIdentifier:@"com.sprouted.avi"],
					nil)
				forAttribute:NSAccessibilityDescriptionAttribute];
		
	}
	else 
	{
		[mPlayer pause:sender];
		[mRecordPauseButton accessibilitySetOverrideValue:NSLocalizedStringFromTableInBundle(
					@"play description",
					@"Localizable",
					[NSBundle bundleWithIdentifier:@"com.sprouted.avi"],
					nil) 
				forAttribute:NSAccessibilityDescriptionAttribute];
		
	}
	
	mPlayingMovie = !mPlayingMovie;
}

- (IBAction) changePlaybackVolume:(id)sender 
{	
	[[mPlayer movie] setVolume:[sender floatValue]];
	[mVolumeImage setImage:[self volumeImage:[sender floatValue] minimumVolume:[sender minValue]]];
}

- (IBAction) changePlaybackLocation:(id)sender 
{	
	// changes the playback position in response to slider movement
	
	double location = [sender doubleValue];
	double timeScale = [[mPlayer movie] currentTime].timeScale;
	
	QTTime locationAsTime = { (long long )location, (long)timeScale, 0 };
	[[mPlayer movie] setCurrentTime:locationAsTime];
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

- (void) playlockCallback:(NSTimer*)aTimer 
{
	// called to update the playback position on the playlock slider
	
	NSString *timeString;
	QTTime current = [[mPlayer movie] currentTime];
	
	[mPlaybackLocSlider setDoubleValue:current.timeValue];
	
	timeString = QTStringFromTime(current);
	[mTimeField setStringValue:[timeString substringWithRange:NSMakeRange(2, 8)]];	
}

- (void) movieEndedCallback:(NSNotification*)aNotification 
{
	// a callpack when the movie ends
	// reset the play button and playing status
	
	mPlayingMovie = NO;
	[mRecordPauseButton setState:NSOffState];
}

#pragma mark -

- (IBAction) fastForward:(id)sender 
{
	[mPlayer stepForward:self];
	[mRecordPauseButton setState:NSOffState];
	[self playlockCallback:nil];
	mPlayingMovie = NO;
}

- (IBAction) rewind:(id)sender 
{
	[mPlayer stepBackward:self];
	[mRecordPauseButton setState:NSOffState];
	[self playlockCallback:nil];
	mPlayingMovie = NO;
}

#pragma mark -

- (IBAction) saveRecording:(id)sender
{
	// insert the recording
	id theTarget = [NSApp targetForAction:@selector(sproutedVideoRecorder:insertRecording:title:) to:nil from:self];
	if ( theTarget != nil ) 
	{
		mUnsavedRecording = NO; // doesn't (can't) take into account a user cancellation
		[theTarget sproutedVideoRecorder:self insertRecording:[self moviePath] title:nil];
	}
	else
	{
		NSBeep();
		NSLog(@"%@ %s - invalid target", [self className], _cmd);
	}
}

#pragma mark -

- (void)updateAudioLevels:(NSTimer *)aTimer
{
	// update the timer if recording
	if ( mRecording )
		[self updateTimeAndSizeDisplay:aTimer];
	
	// Get the mean audio level from the movie file output's audio connections
	float totalDecibels = 0.0;
	
	QTCaptureConnection *connection = nil;
	NSUInteger i = 0;
	NSUInteger numberOfPowerLevels = 0;	// Keep track of the total number of power levels in order to take the mean
	
	for (i = 0; i < [[mCaptureMovieFileOutput connections] count]; i++) 
	{
		connection = [[mCaptureMovieFileOutput connections] objectAtIndex:i];
		
		// QTCaptureConnectionAudioAveragePowerLevelsAttribute
		// QTCaptureConnectionAudioPeakHoldLevelsAttribute
		
		if ([[connection mediaType] isEqualToString:QTMediaTypeSound]) 
		{
			NSArray *powerLevels = [connection attributeForKey:QTCaptureConnectionAudioAveragePowerLevelsAttribute];
			NSUInteger j, powerLevelCount = [powerLevels count];
			
			for (j = 0; j < powerLevelCount; j++) 
			{
				NSNumber *decibels = [powerLevels objectAtIndex:j];
				totalDecibels += [decibels floatValue];
				numberOfPowerLevels++;
			}
		}
	}
	
	if (numberOfPowerLevels > 0 )
		[mAudioLevelMeter setFloatValue:(pow(10., 0.05 * (totalDecibels / (float)numberOfPowerLevels)) * 51.0)];
	else
		[mAudioLevelMeter setFloatValue:0];
}

- (void) updateTimeAndSizeDisplay:(NSTimer*)aTimer
{
	// update the seconds
	int totalSeconds = (int)(GetCurrentEventTime() - mRecordingStart);
	
	int hours = (int)(floor(totalSeconds / 3600));
	int hoursLeftover = (int)(floor(totalSeconds % 3600));
	
	int minutes = (int)(floor(hoursLeftover / 60 ));
	int seconds = (int)floor(hoursLeftover) % 60;
	
	[mTimeField setStringValue:[NSString stringWithFormat:@"%i%i:%i%i:%i%i",
			hours/10,
			hours%10,
			minutes/10,
			minutes%10,
			seconds/10,
			seconds%10]];

	// update the size
	UInt64 totalSize = [mCaptureMovieFileOutput recordedFileSize] / 1024; // = kBytes
	UInt64 mbs = totalSize / 1000;
	UInt64 kbs = (totalSize % 1000) / 100;
	
	[mSizeField setStringValue:[NSString stringWithFormat:@"%qu.%quMB", mbs, kbs]];
}

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
