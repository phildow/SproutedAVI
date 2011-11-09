//
//  SproutedTigerAudioRecorder.m
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


#import <SproutedAVI/SproutedTigerAudioRecorder.h>
#import <SproutedAVI/SproutedAVIAlerts.h>
#import <SproutedAVI/PDMeteringView.h>
#import <SproutedAVI/PDMovieSlider.h>

#import <SproutedAVI/WhackedDebugMacros.h>
#import <SproutedAVI/SeqGrab.h>
#import <SproutedAVI/SGAudio.h>

#define kMeterTimerInterval			1.0/15
#define kPlaybacklockTimerInterval	1.0/30
#define	kInitialGain				0.45

#define kFormatQuickTimeMovie		0
#define kFormatMP3					1

#define kScriptWasCancelledError -128

@implementation SproutedTigerAudioRecorder

- (id) initWithController:(SproutedAVIController*)controller
{   
	if ( self = [super initWithController:controller] ) 
	{
		[NSBundle loadNibNamed:@"AudioRecorder" owner:self];
		
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
		
		#ifdef __DEBUG__
		NSLog([self movPath]);
		#endif
		
		// remove any existing files
		if ( [[NSFileManager defaultManager] fileExistsAtPath:[self movPath]] )
			[[NSFileManager defaultManager] removeFileAtPath:[self movPath] handler:self];
			
		if ( [[NSFileManager defaultManager] fileExistsAtPath:[self mp3Path]] )
			[[NSFileManager defaultManager] removeFileAtPath:[self mp3Path] handler:self];
		
		// set up a mutex for multithreaded protection
		mMutex = QTMLCreateMutex();
		
		// sequence grabber
		mGrabber = [[SeqGrab alloc] init];
		if ( mGrabber == nil )
		{
			// error that the app will have to deal with
			[self release];
			return nil;
		}
		else
		{
			[mGrabber setIdleFrequency:50];
			seqGrab = [mGrabber seqGrabComponent];
		}
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
	if ( ![self isMemberOfClass:[SproutedTigerAudioRecorder class]] )
		return NO;
	
	[insertButton setEnabled:NO];
	[recProgress setUsesThreadedAnimation:YES];
	[mMeteringView setNumChannels:1];
	[volumeSlider setFloatValue:kInitialGain];
	
	return YES;
}

- (BOOL) recorderDidLoad:(NSNotification*)aNotification
{
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
	
	return success;
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
	BOOL success = NO;
	
	if ( ![self _addAudioTrack] )
	{
		success = NO;
		
		[self setRecordingDisabled:YES];
		NSLog(@"%@ %s - unable to add audio track", [self className], _cmd);
	}
	else
	{
		success = YES;
		mChannelNumber = 0;
		
		// start previewing
		if ( [[mGrabber channels] count] > 0)
		{
			[mGrabber preview];
		}
		
		// update the channel gain to reflect the volume on the slider
		[self setChannelGain:volumeSlider];
		
		// start the timers going
		mUpdateMeterTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:.1] 
				interval:kMeterTimerInterval 
				target:self
				selector:@selector(meterTimerCallback:) 
				userInfo:nil 
				repeats:YES];
		
		idleTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:.1] 
				interval:kEventDurationSecond/60 
				target:self
				selector:@selector(idleTimerCallback:) 
				userInfo:nil 
				repeats:YES];
		
		[[NSRunLoop currentRunLoop] addTimer:mUpdateMeterTimer forMode:NSDefaultRunLoopMode];
		[[NSRunLoop currentRunLoop] addTimer:idleTimer forMode:NSDefaultRunLoopMode];
	}
	
	return success;
}

- (BOOL) _addAudioTrack
{
	BOOL success = NO;
	
	[mGrabber stop];
	SGAudio * audi = [[SGAudio alloc] initWithSeqGrab:mGrabber];
	
	// set the default preview volume very low to prevent 
	// feedback loop from microphone near speakers
    Float32 masterVolume = 0.05;
    NSString * prevDevice = nil;
    int i;
    
    if (audi != nil)
    {
		success = YES;
		
		OSErr err = noErr;
		BOOL recordMetersWereEnabled, outputMetersWereEnabled, doEnable = YES;
		
		AudioStreamBasicDescription oldDescription = { 0 };
		AudioStreamBasicDescription newDescription = { 0 };
		
		// Want to perform custom set-up on the audi channel?  Do it here.
		[audi setUsage:seqGrabPreview + seqGrabRecord + seqGrabPlayDuringRecord];

		// instead of just setting the master gain of the preview device very low,
		// first find out if there are any other audi channels using this
		// preview device.  If there are, retain their current volume
        [audi getPropertyWithClass:kQTPropertyClass_SGAudioPreviewDevice 
				id:kQTSGAudioPropertyID_DeviceUID 
				size:sizeof(prevDevice) 
				address:&prevDevice 
				sizeUsed:NULL];
            
            
        for (i = 0; i < [[mGrabber channels] count]; i++)
        {
            SGChan * chan = [[mGrabber channels] objectAtIndex:i];
            if (chan != audi && [chan isAudioChannel])
            {
                NSString * tempDev = nil;
                [(SGAudio*)chan getPropertyWithClass: kQTPropertyClass_SGAudioPreviewDevice 
						id:kQTSGAudioPropertyID_DeviceUID 
						size:sizeof(tempDev) 
						address:&tempDev 
						sizeUsed:NULL];
                    
                if ([prevDevice isEqualToString:tempDev])
                {
                    [(SGAudio*)chan getPropertyWithClass:kQTPropertyClass_SGAudioPreviewDevice 
							id:kQTSGAudioPropertyID_MasterGain 
							size:sizeof(masterVolume) 
							address:&masterVolume 
							sizeUsed:NULL];
                        
                    [tempDev release];
                    break;
                }
                [tempDev release];
            }
        }
        
		[audi setPropertyWithClass:kQTPropertyClass_SGAudioPreviewDevice
				id:kQTSGAudioPropertyID_MasterGain 
				size:sizeof(Float32) 
				address:&masterVolume];
        
		// note the audio channel
		audioChan = [audi chanComponent];
		
		// enable level metering
		err = QTGetComponentProperty(audioChan, 
				kQTPropertyClass_SGAudioRecordDevice, 
				kQTSGAudioPropertyID_LevelMetersEnabled, 
				sizeof(recordMetersWereEnabled), 
				&recordMetersWereEnabled, 
				NULL);

		if ( err ) NSLog(@"%@ %s - Unable to get metering property on the hardware side (%d)", err, [self className], _cmd);
		
		if (recordMetersWereEnabled != doEnable)
		{
			err = QTSetComponentProperty(audioChan, 
					kQTPropertyClass_SGAudioRecordDevice, 
					kQTSGAudioPropertyID_LevelMetersEnabled, 
					sizeof(doEnable), 
					&doEnable);
			
			if ( err ) NSLog(@"%@ %s - Unable to enable metering on the hardware side (%d)", err, [self className], _cmd);
		}
		
		// enable output metering as well
		err = QTGetComponentProperty(audioChan, 
				kQTPropertyClass_SGAudio, 
				kQTSGAudioPropertyID_LevelMetersEnabled, 
				sizeof(outputMetersWereEnabled), 
				&outputMetersWereEnabled, 
				NULL);
		
		if ( err ) NSLog(@"%@ %s - Unable to get metering property on the software side (%d)", err, [self className], _cmd);
		
		if (outputMetersWereEnabled != doEnable)
		{
			err = QTSetComponentProperty(audioChan, 
					kQTPropertyClass_SGAudio, 
					kQTSGAudioPropertyID_LevelMetersEnabled, 
					sizeof(doEnable), 
					&doEnable);
			
			if ( err ) NSLog(@"%@ %s - Unable to enable metering on the software side (%d)", err, [self className], _cmd);
		}
		
		
		// set the audio format based on the old format and new information
		err = QTGetComponentProperty(audioChan, 
				kQTPropertyClass_SGAudio, 
				kQTSGAudioPropertyID_StreamFormat, 
				sizeof(AudioStreamBasicDescription), 
				&oldDescription, 
				NULL);
		
		if ( err != noErr ) NSLog(@"%@ %s - Unable to get audio stream description (%d)", err, [self className], _cmd);
		else
		{
			newDescription.mSampleRate = 48000.;
			newDescription.mFormatID = kAudioFormatMPEG4AAC;

			newDescription.mChannelsPerFrame = oldDescription.mChannelsPerFrame;
			
			newDescription.mFormatFlags = 1; // 'main' or standard aac encoding
			newDescription.mBytesPerPacket = 0;
			newDescription.mFramesPerPacket = 0;
			newDescription.mBytesPerFrame = 0;
			newDescription.mBitsPerChannel = 0;
			newDescription.mReserved = 0;
			
			err = QTSetComponentProperty(audioChan,
					kQTPropertyClass_SGAudio, 
					kQTSGAudioPropertyID_StreamFormat, 
					sizeof(AudioStreamBasicDescription),
					&newDescription);
			
			if ( err != noErr ) NSLog(@"%@ %s - Unable to set audio stream description (%d)", err, [self className], _cmd);
		}
		
		// release the channel. it was retained by its mGrabber
		[audi release]; 
	}
	else 
	{
		success = NO;
		audioChan = NULL;
    }
    
	// clean up
    [prevDevice release];
	
	return success;
}



- (BOOL) takedownRecording 
{	
	if ( !_sequenceComponentsClosed ) 
	{
		// kill the appropriate timers
		[mUpdateMeterTimer invalidate];
		[mUpdateMeterTimer release], mUpdateMeterTimer = nil;
		
		[idleTimer invalidate];
		[idleTimer release], idleTimer = nil;
	
		// stop previewing, playing and recording
		[mGrabber stop];
		
		// release the grabber, shutting everything down
		[mGrabber release], mGrabber = nil;
		
		seqGrab = NULL;
		audioChan = NULL;
			
		// the mutex
		if ( mMutex != nil ) QTMLDestroyMutex(mMutex);
		
		// make sure this doesn't happen again
		_sequenceComponentsClosed = YES;
	}
	
	return YES;
}

#pragma mark -

- (IBAction) stopRecording:(id)sender
{
	if ( _recording )
	{
		OSStatus err;
		
		_recording = NO;
		_unsavedRecording = YES;
		
		if ( ( err = [mGrabber stop] ) != noErr ) 
			NSLog(@"%@ %s - unable to stop recording (%d)", [self className], _cmd, err);
	}
}

- (IBAction) startRecording:(id)sender
{
	if ( !_recording )
	{
		OSStatus err;
		
		err = [mGrabber stop];
		if (err != noErr) NSLog(@"%@ %s - unable to stop recording (%d)", [self className], _cmd, err);
		
		// use the capture path set in mCaptureToField
		err = [self setCapturePath:[self movPath] flags:(seqGrabToDisk|seqGrabDontPreAllocateFileSize)];
		if (err == noErr)
		{
			err = [mGrabber record];
			if ( err == noErr )
			{
				_recording = YES;
				_recordingStart = GetCurrentEventTime();
				
				[recordButton accessibilitySetOverrideValue:NSLocalizedStringFromTableInBundle(
							@"stop description",
							@"Localizable",
							[NSBundle bundleWithIdentifier:@"com.sprouted.avi"],
							nil)
						forAttribute:NSAccessibilityDescriptionAttribute];
			}
			else
			{
				NSLog(@"%@ %s - unable to begin recording!", [self className], _cmd);
				
				[[NSAlert unableToStartRecording] runModal];
				[self takedownRecording];
			}
		}
		else
		{
			NSLog(@"%@ %s - unable to set the capture path for the audio file to %@", [self className], _cmd, [self movPath]);
			
			[[NSAlert unableToStartRecording] runModal];
			[self takedownRecording];
		}
	}
}

#pragma mark -

- (void) prepareForPlaying 
{	
	// completely stop the sequence grabber and remove the data proc
	// no longer previewing or recording
	[self takedownRecording];
	
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
	NSPoint playlockFrame = [mMeteringView frame].origin;
	
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
			mMeteringView, NSViewAnimationTargetKey, 
			NSViewAnimationFadeOutEffect, NSViewAnimationEffectKey, nil] autorelease];

	NSViewAnimation *theAnim = [[NSViewAnimation alloc] initWithViewAnimations:
			[NSArray arrayWithObjects:theDict, otherDict, playbackDict, meteringDict, nil]];
	
	[theAnim startAnimation];
	
	// remove the metering view once the animation is complete
	[mMeteringView removeFromSuperview];
	[insertButton setEnabled:YES];
	
	// clean up
	[theAnim release];
	[playbackLocSlider release];
}


#pragma mark -

- (OSStatus)setCapturePath:(NSString *)path flags:(long)flags
{
	OSStatus err = noErr;
    BOOL isPreviewing = [mGrabber isPreviewing];
	
    if (isPreviewing)
        [mGrabber stop];
        
	BAILSETERR( [mGrabber setCapturePath:path flags:flags] );
    
    if (isPreviewing)
        [mGrabber preview];
    
bail:
	return err;
}

- (IBAction)setChannelGain:(id)sender
{
	OSErr err;
	Float32 myValue = [sender floatValue];
	UInt32 size, flags;
	
	BOOL useAudioDevice = NO;
	BOOL useMasterGain = NO;
		
	// this is setting the master gain on the harware side
	// if that does not work, set it on the system side
	
	// get the number of channels by querying the size variable
	// kQTPropertyClass_SGAudioPreviewDevice
	
	//Float32 level = [mRecMasterGainSlider floatValue];
    //ComponentPropertyClass propClass = 
	//	([mUseHardwareGainButton state] == NSOnState) ? kQTPropertyClass_SGAudioRecordDevice 
	//												  : kQTPropertyClass_SGAudio;
	
	// kQTPropertyClass_SGAudioPreviewDevice
	// kQTPropertyClass_SGAudioRecordDevice
	// kQTPropertyClass_SGAudio
	// NSLog([[NSNumber numberWithFloat:myValue] description]);
	// err = QTSetComponentProperty(audioChan,kQTPropertyClass_SGAudio,
	//			kQTSGAudioPropertyID_MasterGain,sizeof(myValue),&myValue);
	
beginning:
	
	err = QTGetComponentPropertyInfo(audioChan, 
			kQTPropertyClass_SGAudioRecordDevice, 
			kQTSGAudioPropertyID_PerChannelGain, 
			NULL, 
			&size, 
			&flags);
	
	if ( err == noErr && size && (flags & kComponentPropertyFlagCanSetNow) ) 
	{
		Float32 * chanGains = (Float32*)malloc(size * sizeof(Float32));
		UInt32 numChannelGains = size/sizeof(Float32);
		
		int i;
		for ( i = 0; i < numChannelGains; i++ )
			chanGains[i] = myValue;

		err = QTSetComponentProperty(audioChan,
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
		err = QTGetComponentPropertyInfo(audioChan, 
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
			err = QTSetComponentProperty(audioChan,
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
		err = QTSetComponentProperty(audioChan,
				kQTPropertyClass_SGAudio,
				kQTSGAudioPropertyID_MasterGain, 
				sizeof(myValue),
				&myValue);
		
		if ( err != noErr ) NSLog(@"%@ %s - last resort, tried to set master gain, didn't work (%d)", [self className], _cmd, err);
	}
	
ending:
	
	[volumeImage setImage:[self volumeImage:myValue minimumVolume:[sender minValue]]];

}

- (IBAction) togglePlaythru:(id)sender 
{	
	OSErr err;
	BOOL playthru = ([sender state] == NSOnState);
	
	err = QTSetComponentProperty(audioChan, 
			kQTPropertyClass_SGAudioRecordDevice, 
			kQTSGAudioPropertyID_HardwarePlaythruEnabled, 
			sizeof(BOOL), 
			&playthru); 
	
	if ( err ) NSLog(@"%@ %s - nable to disable the hardware playthru, (%d)", [self className], _cmd, err);
}


#pragma mark -

- (void)idleTimerCallback:(NSTimer*)timer
{
	SGIdle(seqGrab);
}

- (void) meterTimerCallback:(NSTimer*)timer 
{	
	// update the time if recording
	if ( _recording ) [self updateTimer];
	
	// update the channel levels in any case
	[self updateChannelLevel];
}

- (void) updateTimer
{
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
}

- (void) updateChannelLevel
{
    OSErr err;
	Float32 amps[2] = { -FLT_MAX, -FLT_MAX };
    
	if ( !QTMLTryGrabMutex(mMutex) )
		return;
	
    QTMLGrabMutex(mMutex);
	
	if (mLevelsArray == NULL)
	{    
		UInt32 size;
		
		err = QTGetComponentPropertyInfo( audioChan, 
				kQTPropertyClass_SGAudioRecordDevice, 
				kQTSGAudioPropertyID_ChannelMap, 
				NULL, 
				&size, 
				NULL );
		
		if (size > 0)
		{
			SInt32 * map = (SInt32 *)malloc(size);
			
			err = QTGetComponentProperty(audioChan, 
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
	
	// paranoia
	if (mLevelsArray) 
	{
		// get the avg power level
		
		err = QTGetComponentProperty(audioChan, 
				kQTPropertyClass_SGAudioRecordDevice, 
				kQTSGAudioPropertyID_AveragePowerLevels, 
				mLevelsArraySize, 
				mLevelsArray, 
				NULL);
		
		if ( err == noErr )
			amps[0] = mLevelsArray[mMyIndex];
		
		// get the peak hold level
		err = QTGetComponentProperty(audioChan, 
				kQTPropertyClass_SGAudioRecordDevice, 
				kQTSGAudioPropertyID_PeakHoldLevels, 
				mLevelsArraySize, 
				mLevelsArray,
				NULL);
		
		if ( err = noErr ) amps[1] = mLevelsArray[mMyIndex];
	}
	
    QTMLReturnMutex(mMutex);
    [mMeteringView updateMeters:amps];
}


@end
