//
//  SproutedLeopardAudioRecorder.m
//  Sprouted AVI
//
//  Created by Philip Dow on 5/1/08.
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


#import <SproutedAVI/SproutedLeopardAudioRecorder.h>
#import <SproutedAVI/SproutedAVIAlerts.h>
#import <SproutedAVI/PDMovieSlider.h>

#define kMeterTimerInterval			1.0/15
#define kPlaybacklockTimerInterval	1.0/30
#define	kInitialGain				0.45

#define kFormatQuickTimeMovie		0
#define kFormatMP3					1

#define kScriptWasCancelledError -128

@implementation SproutedLeopardAudioRecorder

- (id) initWithController:(SproutedAVIController*)controller
{   
	if ( self = [super initWithController:controller] ) 
	{
		[NSBundle loadNibNamed:@"AudioRecorder_105" owner:self];
		
		_unsavedRecording = NO;
		
		// set up some default recording info
		[self setRecordingTitle:[NSString string]];
		[self setRecordingDate:[NSCalendarDate calendarDate]];
		
		// the save location
		NSString *tempDir = [self cachesFolder];
		if ( tempDir == nil )
		{
			tempDir = NSTemporaryDirectory();
			if ( tempDir == nil ) tempDir = [NSString stringWithString:@"/tmp"];
		}
		else
		{
			tempDir = [tempDir stringByAppendingPathComponent:@"com.sprouted.avi.audiorecorder"];
			if ( ![[NSFileManager defaultManager] fileExistsAtPath:tempDir] )
			{
				if ( ![[NSFileManager defaultManager] createDirectoryAtPath:tempDir attributes:nil] )
				{
					tempDir = NSTemporaryDirectory();
					if ( tempDir == nil ) tempDir = [NSString stringWithString:@"/tmp"];
				}
			}
		}
		
		// the actual file
		NSString *dateTime = [[NSDate date] descriptionWithCalendarFormat:@"%H%M%S" timeZone:nil locale:nil];
		[self setMovPath:[tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mov", dateTime]]];
		[self setMp3Path:[tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp3", dateTime]]];
		
		// remove any existing files
		if ( [[NSFileManager defaultManager] fileExistsAtPath:[self movPath]] )
			[[NSFileManager defaultManager] removeFileAtPath:[self movPath] handler:self];
			
		if ( [[NSFileManager defaultManager] fileExistsAtPath:[self mp3Path]] )
			[[NSFileManager defaultManager] removeFileAtPath:[self mp3Path] handler:self];
	}
	
    return self;
}

#pragma mark -

- (BOOL) recorderShouldClose:(NSNotification*)aNotification error:(NSError**)anError
{
	BOOL shouldClose = YES;
	
	if ( _recording )
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
	if ( ![self isMemberOfClass:[SproutedLeopardAudioRecorder class]] )
		return NO;
	
	BOOL success = [self setupRecording];
	if ( !success)
	{
		[self takedownRecording];
		
		NSString *errorMessage = NSLocalizedStringFromTableInBundle(
				@"no audio capture msg", 
				@"Localizable", 
				[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
				@"");
		NSString *errorInfo = NSLocalizedStringFromTableInBundle(
				@"no audio capture info", 
				@"Localizable", 
				[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
				@"");
				
		NSString *myError = [NSString stringWithFormat:@"%@\n\n%@", errorMessage, errorInfo];
		[self setError:myError];
	}
	else
	{
		[insertButton setEnabled:NO];
		[recProgress setUsesThreadedAnimation:YES];
		[volumeSlider setFloatValue:kInitialGain];
	}
	
	return success;
}

- (BOOL) recorderDidLoad:(NSNotification*)aNotification
{
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
	// must be performed before deallocation
	// deallocation won't occur otherwise
	[self takedownRecording];
	
	[recorderController unbind:@"contentObject"];
	[recorderController setContent:nil];
	
	[player pause:self];
	[player setMovie:nil];

	if ( updatePlaybackLocTimer ) 
	{
		[updatePlaybackLocTimer invalidate];
		[updatePlaybackLocTimer release], updatePlaybackLocTimer = nil;
	}

	if ( [[NSFileManager defaultManager] fileExistsAtPath:[self movPath]] )
		[[NSFileManager defaultManager] removeFileAtPath:[self movPath] handler:self];
		
	if ( [[NSFileManager defaultManager] fileExistsAtPath:[self mp3Path]] )
		[[NSFileManager defaultManager] removeFileAtPath:[self mp3Path] handler:self];
		
	return YES;
}

#pragma mark -

- (BOOL) setupRecording
{
	// Create the capture session
	mCaptureSession = [[QTCaptureSession alloc] init];
    
	// Connect inputs and outputs to the session	
	BOOL success = NO;
	NSError *localError;
	
	QTCaptureDevice *audioDevice = [QTCaptureDevice defaultInputDeviceWithMediaType:QTMediaTypeSound];
	success = [audioDevice open:&localError];
	
	if (!success) 
	{
		audioDevice = nil;
		[self setError:[self audioCaptureError]];
		goto bail;
	}
	else if (audioDevice) 
	{
		mCaptureAudioDeviceInput = [[QTCaptureDeviceInput alloc] initWithDevice:audioDevice];
		success = [mCaptureSession addInput:mCaptureAudioDeviceInput error:&localError];
		if (!success)
		{
			// Handle error
			[self setError:[self audioCaptureError]];
			goto bail;
		}
	}
	
	// Create the movie file output and add it to the session
	mCaptureMovieFileOutput = [[QTCaptureMovieFileOutput alloc] init];
	success = [mCaptureSession addOutput:mCaptureMovieFileOutput error:&localError];
	if (!success) 
	{
		// Handle error
		[self setError:[self audioCaptureError]];
		goto bail;
	}
	
	[mCaptureMovieFileOutput setDelegate:self];
	
	// Set the compression for the audio/video that is recorded to the hard disk.
	NSEnumerator *connectionEnumerator = [[mCaptureMovieFileOutput connections] objectEnumerator];
	QTCaptureConnection *connection;
	
	NSString *audioCompression = @"QTCompressionOptionsHighQualityAACAudio";
	
	// iterate over each output connection for the capture session and specify the desired compression
	while ( (connection = [connectionEnumerator nextObject]) ) 
	{
		NSString *mediaType = [connection mediaType];
		QTCompressionOptions *compressionOptions = nil;
		
		// specify the video and audio compression options
		// (note: a list of other valid compression types can be found in the QTCompressionOptions.h interface file)
		if ([mediaType isEqualToString:QTMediaTypeSound]) 
		{
			// use AAC Audio: @"QTCompressionOptionsHighQualityAACAudio"
			compressionOptions = [QTCompressionOptions compressionOptionsWithIdentifier:audioCompression];
		}
		
		// set the compression options for the movie file output
		[mCaptureMovieFileOutput setCompressionOptions:compressionOptions forConnection:connection];
	}

bail:
	
	return success;
}

- (BOOL) takedownRecording
{
	if (mAudioLevelTimer != nil)
	{
		[mAudioLevelTimer invalidate];
		[mAudioLevelTimer release], mAudioLevelTimer = nil;
	}
	
	if ( [mCaptureSession isRunning] )
		[mCaptureSession stopRunning];
    
    if ([[mCaptureAudioDeviceInput device] isOpen])
        [[mCaptureAudioDeviceInput device] close];
	
	return YES;
}

#pragma mark -
#pragma mark Making the Recording

- (IBAction)recordPause:(id)sender
{
	if ( _recording )
	{
		[self stopRecording:sender];
		[recordButton accessibilitySetOverrideValue:NSLocalizedStringFromTableInBundle(
					@"play description",
					@"Localizable",
					[NSBundle bundleWithIdentifier:@"com.sprouted.avi"],
					nil)
				forAttribute:NSAccessibilityDescriptionAttribute];
	}
	else 
	{
		[self startRecording:sender];
		[recordButton accessibilitySetOverrideValue:NSLocalizedStringFromTableInBundle(
					@"stop description",
					@"Localizable",
					[NSBundle bundleWithIdentifier:@"com.sprouted.avi"],
					nil)
				forAttribute:NSAccessibilityDescriptionAttribute];
	}
}

- (IBAction) startRecording:(id)sender
{
	_recording = YES;
	_recordingStart = GetCurrentEventTime();
	[mCaptureMovieFileOutput recordToOutputFileURL:[NSURL fileURLWithPath:[self movPath]]];
}

- (IBAction) stopRecording:(id)sender
{
	if ( _recording )
	{
		_recording = NO;
		_unsavedRecording = YES;
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
	[volumeImage setImage:[self volumeImage:[sender floatValue] minimumVolume:[sender minValue]]];
}

#pragma mark -

- (void)captureOutput:(QTCaptureFileOutput *)captureOutput 
		didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL 
		forConnections:(NSArray *)connections 
		dueToError:(NSError *)error
{
	[self takedownRecording];
	[self prepareForPlaying];
}

- (void) prepareForPlaying 
{	
	// switch the preview view out and replace it with the quicktime view
	
	if ( [QTMovie canInitWithFile:[self movPath]] ) 
	{
		// prepare the movie
		QTMovie *movie = [[QTMovie alloc] initWithFile:[self movPath] error:nil];
		
		// play the movie
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
		[[NSNotificationCenter defaultCenter] addObserver:self 
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
		[[NSAlert unreadableAudioFile] runModal];
		
		[recordButton setEnabled:NO];
		[fastforward setEnabled:NO];
		[rewind setEnabled:NO];
	}
	
	// set the record button to play/pause mode
	NSBundle *myBundle = [NSBundle bundleWithIdentifier:@"com.sprouted.avi"];
	
	[recordButton setImage:[[[NSImage alloc] initWithContentsOfFile:[myBundle pathForImageResource:@"playrecording.png"]] autorelease]];
	[recordButton setAlternateImage:[[[NSImage alloc] initWithContentsOfFile:[myBundle pathForImageResource:@"pauserecording.png"]] autorelease]];
	[recordButton setAction:@selector(playPause:)];
	
	// make the playback slider visible and hide the metering view
	NSPoint playlockFrame = [mAudioLevelMeter frame].origin;
	
	[playbackLocSlider retain];
	[playbackLocSlider removeFromSuperviewWithoutNeedingDisplay];
	[playbackLocSlider setFrameOrigin:playlockFrame];
	
	// get the playback slider ready to fade in
	[playbackLocSlider setHidden:YES];
	[[self view] addSubview:playbackLocSlider];
	
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
			mAudioLevelMeter, NSViewAnimationTargetKey, 
			NSViewAnimationFadeOutEffect, NSViewAnimationEffectKey, nil] autorelease];

	NSViewAnimation *theAnim = [[NSViewAnimation alloc] initWithViewAnimations:
			[NSArray arrayWithObjects:theDict, otherDict, playbackDict, meteringDict, nil]];
	
	[theAnim startAnimation];
	
	// remove the metering view once the animation is complete
	[mAudioLevelMeter removeFromSuperview];
	[insertButton setEnabled:YES];
	
	// clean up
	[theAnim release];
	[playbackLocSlider release];
}

#pragma mark -
#pragma mark Playing the Recording

- (IBAction) changePlaybackVolume:(id)sender 
{	
	[[player movie] setVolume:[sender floatValue]];
	[volumeImage setImage:[self volumeImage:[sender floatValue] minimumVolume:[sender minValue]]];
}

- (IBAction)playPause:(id)sender 
{	
	if ( !_playingMovie ) 
	{
		[recordButton accessibilitySetOverrideValue:NSLocalizedStringFromTableInBundle(
					@"stop description",
					@"Localizable",
					[NSBundle bundleWithIdentifier:@"com.sprouted.avi"],
					nil)
				forAttribute:NSAccessibilityDescriptionAttribute];
		
		[player play:sender];
	}
	else 
	{
		[recordButton accessibilitySetOverrideValue:NSLocalizedStringFromTableInBundle(
					@"play description", 
					@"Localizable",
					[NSBundle bundleWithIdentifier:@"com.sprouted.avi"],
					nil)
				forAttribute:NSAccessibilityDescriptionAttribute];
		
		[player pause:sender];
	}
	
	_playingMovie = !_playingMovie;
}

- (IBAction) fastForward:(id)sender 
{
	[player stepForward:self];
	[recordButton setState:NSOffState];
	[self playlockCallback:nil];
	
	_playingMovie = NO;
}

- (IBAction) rewind:(id)sender 
{
	[player stepBackward:self];
	[recordButton setState:NSOffState];
	[self playlockCallback:nil];
	
	_playingMovie = NO;
}

#pragma mark -

- (void) playlockCallback:(NSTimer*)aTimer 
{
	// called to update the playback position on the playlock slider
	
	NSString *timeString;
	QTTime current;
	
	current = [[player movie] currentTime];
	[playbackLocSlider setDoubleValue:current.timeValue];
	
	timeString = QTStringFromTime(current);
	if ( timeString != nil ) [timeField setStringValue:[timeString substringWithRange:NSMakeRange(2, 8)]];
	
}

- (void) movieEnded:(NSNotification*)aNotification 
{
	// a callpack when the movie ends - reset the play button and playing status
	
	_playingMovie = NO;
	[recordButton setState:NSOffState];	
}

#pragma mark -

- (void)updateAudioLevels:(NSTimer *)aTimer
{
	// update the timer if recording
	if ( _recording )
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
	UInt64 totalSize = [mCaptureMovieFileOutput recordedFileSize] / 1024; // = kBytes
	UInt64 mbs = totalSize / 1000;
	UInt64 kbs = (totalSize % 1000) / 100;
	
	[sizeField setStringValue:[NSString stringWithFormat:@"%qu.%quMB", mbs, kbs]];
}

@end
