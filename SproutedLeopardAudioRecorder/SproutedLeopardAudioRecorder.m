//
//  SproutedLeopardAudioRecorder.m
//  Sprouted AVI
//
//  Created by Philip Dow on 5/1/08.
//  Copyright 2008 Lead Developer, Journler Software. All rights reserved.
//

#import <SproutedAVI/SproutedLeopardAudioRecorder.h>
#import <SproutedAVI/SproutedAudioRecorder.h>

#import <SproutedAVI/SproutedLAMEInstaller.h>
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
		[self setRecTitle:[NSString string]];
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

- (void) dealloc
{
	// recording related items
	[self takedownRecording];
	
	if ( updatePlaybackLocTimer ) 
	{
		[updatePlaybackLocTimer invalidate];
		[updatePlaybackLocTimer release], updatePlaybackLocTimer = nil;
	}
	
	[_recTitle release], _recTitle = nil;
	[_recArtist release], _recArtist = nil;
	[_recAlbum release], _recAlbum = nil;
	[_recordingDate release], _recordingDate = nil;
	
	[movPath release], movPath = nil;
	[mp3Path release], mp3Path = nil;
	
	// top level nib objects
	[recorderController release], recorderController = nil;
	[playbackLockHolder release], playbackLockHolder = nil;
	[recProgressWin release], recProgress = nil;
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[super dealloc];
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
				
		NSString *myError = [NSString stringWithFormat:@"%@ %@", errorMessage, errorInfo];
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

- (BOOL) recordingDisabled 
{ 
	return recordingDisabled; 
}

- (void) setRecordingDisabled:(BOOL)disabled 
{
	recordingDisabled = disabled;
}

- (int) saveAction
{
	return saveAction;
}

- (void) setPathTitle:(NSString*)aString 
{
	NSString *tempDir = [self cachesFolder];
	if ( tempDir == nil )
	{
		tempDir = NSTemporaryDirectory();
		if ( tempDir == nil ) tempDir = [NSString stringWithString:@"/tmp"];
	}
	else
	{
		tempDir = [tempDir stringByAppendingPathComponent:@"com.sprouted.SproutedAudioRecorder"];
		if ( ![[NSFileManager defaultManager] fileExistsAtPath:tempDir] )
		{
			if ( ![[NSFileManager defaultManager] createDirectoryAtPath:tempDir attributes:nil] )
			{
				tempDir = NSTemporaryDirectory();
				if ( tempDir == nil ) tempDir = [NSString stringWithString:@"/tmp"];
			}
		}
	}
	
	NSString *tempMp3Path = [tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp3", aString]];
	[self setMp3Path:tempMp3Path];
}

- (NSString*) movPath 
{ 
	return movPath; 
}

- (void) setMovPath:(NSString*)path 
{
	if ( movPath != path ) 
	{
		[movPath release];
		movPath = [path copyWithZone:[self zone]];
	}
}

- (NSString*) mp3Path 
{ 
	return mp3Path; 
}

- (void) setMp3Path:(NSString*)path 
{
	if ( mp3Path != path ) 
	{
		[mp3Path release];
		mp3Path = [path copyWithZone:[self zone]];
	}
}

#pragma mark -

- (NSString*) recTitle 
{ 
	return _recTitle; 
}

- (void) setRecTitle:(NSString*)title 
{
	if ( _recTitle != title ) 
	{
		[_recTitle release];
		_recTitle = [title copyWithZone:[self zone]];
	}
}

- (NSString*) recArtist 
{ 
	NSString *theArtist = [[NSUserDefaults standardUserDefaults] stringForKey:@"DefaultArtist"];
	if ( theArtist == nil ) theArtist = [NSString string];
	return theArtist;
}

- (void) setRecArtist:(NSString*)artist 
{
	if ( _recArtist != artist ) 
	{
		[_recArtist release];
		_recArtist = [artist copyWithZone:[self zone]];
	}
}

- (NSString*) recAlbum 
{ 
	NSString *theAlbum = [[NSUserDefaults standardUserDefaults] stringForKey:@"DefaultAlbum"];
	if ( theAlbum == nil ) theAlbum = [NSString string];
	return theAlbum;
}

- (void) setRecAlbum:(NSString*)album 
{
	if ( _recAlbum != album ) 
	{
		[_recAlbum release];
		_recAlbum = [album copyWithZone:[self zone]];
	}
}

- (NSCalendarDate*) recordingDate
{ 
	return _recordingDate; 
}

- (void) setRecordingDate:(NSCalendarDate*)aDate 
{
	if ( _recordingDate != aDate ) 
	{
		[_recordingDate release];
		_recordingDate = [aDate copyWithZone:[self zone]];
	}
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
	[self prepareForPlaying];
	[self takedownRecording];
}

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

- (IBAction) changePlaybackLocation:(id)sender 
{
	// changes the playback position in response to slider movement
	
	double location = [sender doubleValue];
	double timeScale = [[player movie] currentTime].timeScale;
	QTTime locationAsTime = { (long long )location, (long)timeScale, 0 };
	[[player movie] setCurrentTime:locationAsTime];
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
#pragma mark Playing the Recording

- (IBAction) saveRecording:(id)sender
{
	NSString *targetPath = nil;
	NSString *finishedFileLoc = nil;
		
	saveAction = 0;
	int insertFormat = [[NSUserDefaults standardUserDefaults] integerForKey:@"AudioRecordingFormat"];
	
	// save interface changes over bindings
	if ( ![recorderController commitEditing] ) NSLog(@"%@ %s - unable to commit editing", [self className], _cmd);
	
	//should I even bother?
	if ( ![[NSFileManager defaultManager] fileExistsAtPath:[self movPath]] || ![QTMovie canInitWithFile:[self movPath]] ) 
	{
		[[NSAlert unreadableAudioFile] runModal];
		NSLog(@"%@ %s - Unable to begin conversion, could not read saved audio file", [self className], _cmd);
		return;
	}
	
	if ( insertFormat == kFormatQuickTimeMovie )
	{		
		[recProgress startAnimation:self];
		[recProgressText setStringValue:NSLocalizedStringFromTableInBundle(
				@"mov tag",
				@"Localizable",
				[NSBundle bundleWithIdentifier:@"com.sprouted.avi"],
				nil)];
		
		[NSApp beginSheet: recProgressWin 
				modalForWindow:[[self view] window] 
				modalDelegate: nil
				didEndSelector: nil 
				contextInfo: nil];
			
		NSError *localError = nil;
		NSString *resultingPath = nil;
		if ( [self prepareRecording:[self movPath] asMovie:&resultingPath error:&localError] )
		{
			[self setMovPath:resultingPath];
			targetPath = resultingPath;
		}
		else
		{
			targetPath = [self movPath];
		}
	}
	else if ( insertFormat == kFormatMP3 )
	{
		[recProgress startAnimation:self];
		[recProgressText setStringValue:NSLocalizedStringFromTableInBundle(
				@"mp3 convert",
				@"Localizable",
				[NSBundle bundleWithIdentifier:@"com.sprouted.avi"],
				nil)];
		
		[NSApp beginSheet:recProgressWin 
				modalForWindow:[[self view] window] 
				modalDelegate:nil
				didEndSelector:nil 
				contextInfo:nil];
		
		NSError *localError = nil;
		NSString *resultingPath = nil;
		if ( [self prepareRecording:[self movPath] asMP3:&resultingPath error:&localError] )
		{
			targetPath = resultingPath;
		}
		else
		{
			targetPath = nil;
		}
	}
	
	// if there was some problem creating the derivative
	// bail on this operation
	if ( targetPath == nil )
		goto bail;
		
	// does the user want the mp3 to be part of the iTunes library or not
	if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"AddRecordingToITunes"] ) 
	{
		// the standard path - add this guy to iTunes and our playlist
		[recProgressText setStringValue:NSLocalizedStringFromTableInBundle(
				@"mp3 import",
				@"Localizable",
				[NSBundle bundleWithIdentifier:@"com.sprouted.avi"],
				nil)];
		[recProgressWin display];
		
		NSError *localError = nil;
		NSString *resultingPath = nil;
		if ( [self addRecording:targetPath toiTunes:&resultingPath error:&localError] )
		{
			saveAction = kSproutedAudioSavedToiTunes;
			finishedFileLoc = resultingPath;
		}
		else
		{
			goto bail;
		}
	}
	else 
	{
		// the less standard path - save in the entry itself
		saveAction = kSproutedAudioSavedToTemporaryLocation;
		finishedFileLoc = targetPath;
	}
	
	
	// insert the recording
	id theTarget = [NSApp targetForAction:@selector(sproutedAudioRecorder:insertRecording:title:) to:nil from:self];
	if ( theTarget != nil ) 
	{
		_unsavedRecording = NO; // doesn't (can't) take into account a user cancellation
		[theTarget sproutedAudioRecorder:self insertRecording:finishedFileLoc title:[self recTitle]];
	}
	else
	{
		NSBeep();
		NSLog(@"%@ %s - invalid target", [self className], _cmd);
	}		
	
		
bail:
	
	
	// kill the progress window
	[NSApp endSheet:recProgressWin];
	[recProgress stopAnimation:self];
	[recProgressWin orderOut:self];
}

#pragma mark -

- (Component) lameMP3ConverterComponent
{
	Component c = NULL;
	ComponentDescription description;
	
	description.componentType = 'spit';
	description.componentSubType = 'mp3 ';
	description.componentManufacturer = 'PYEh';
	description.componentFlags = 0;
	description.componentFlagsMask = 0;
	
	c = FindNextComponent(0, &description);
	return c;
}

- (int) tagMP3:(NSString*)path
{
	TagAPI *tag = [[[TagAPI alloc] initWithGenreList: nil] autorelease];
	[tag examineFile:path];
	
	[tag setTitle:[self recTitle]];
	[tag setAlbum:[self recAlbum]];
	[tag setArtist:[self recArtist]];
	[tag setYear:[[self recordingDate] yearOfCommonEra]];
	[tag setComments:[NSString stringWithFormat:@"Recorded on %@", [[self recordingDate] description]]];

	return [tag updateFile];
}

- (BOOL) prepareRecording:(NSString*)path asMovie:(NSString**)savedPath error:(NSError**)anError
{
	BOOL success = YES;
	QTMovie *aacMovie = [[QTMovie alloc] initWithFile:path error:nil];
	[self addMovieMetadata:aacMovie];
	
	// rename the movie file and target the path for the import
	NSString *titledPath = [[[[self movPath] stringByDeletingLastPathComponent] 
			stringByAppendingPathComponent:[[self recTitle] pathSafeString]] 
			stringByAppendingPathExtension:@"mov"];
	
	*savedPath = titledPath;
	success = [[NSFileManager defaultManager] movePath:path toPath:titledPath handler:self];
	
	[aacMovie release];
	
	return success;
}

- (BOOL) prepareRecording:(NSString*)path asMP3:(NSString**)savedPath error:(NSError**)anError
{
	BOOL success = YES;
	
	// quicktime specific variables
	QTAtomContainer atomSettings = NULL;
	ComponentResult	componentErr = 0;
	MovieExportComponent exporter = NULL;
	
	NSString *titledPath = nil;
	NSDictionary *settings = nil;
	
	// grab the aifc movie
	NSError *localError = nil;
	QTMovie *aacMovie = [[QTMovie alloc] initWithFile:path error:&localError];
	
	Component c = [self lameMP3ConverterComponent];
	if ( c == nil ) 
	{
		[[NSAlert lameEncoderUnavailable] runModal];
		NSLog(@"%@ %s - Could not find the LAME MP3 encoder component", [self className], _cmd);
		success = NO;
		goto mp3bail;
	}
	
	// open the component
	exporter = OpenComponent(c);
	
	if ( exporter == nil )
	{
		[[NSAlert lameEncoderUnavailable] runModal];
		NSLog(@"Could not open the LAME mp3 encoder component", [self className], _cmd);
		success = NO;
		goto mp3bail;
	}
	
	// component and atom interaction
	componentErr = MovieExportGetSettingsAsAtomContainer(exporter, &atomSettings);
	if ( componentErr ) 
	{
		NSBeep();
		[[NSAlert lameEncoderUnavailable] runModal];
		NSLog(@"Could not get movie export settings", [self className], _cmd);
		success = NO;
		goto mp3bail;
	}
	
	// create the settings that will be used with the QTMovie methods // kQTFileTypeAIFF kQTFileTypeMP4
	settings = [[NSDictionary alloc] initWithObjectsAndKeys:
			[NSNumber numberWithBool:YES], QTMovieExport, 
			[NSNumber numberWithLong:'mp3 '], QTMovieExportType,
			[NSNumber numberWithLong:'PYEh'], QTMovieExportManufacturer, 
			[NSData dataWithBytes:*atomSettings length:GetHandleSize(atomSettings)], QTMovieExportSettings, nil];
	
	// title the mp3 path
	titledPath = [[[[self movPath] stringByDeletingLastPathComponent] 
			stringByAppendingPathComponent:[[self recTitle] pathSafeString]] 
			stringByAppendingPathExtension:@"mp3"];
	
	*savedPath = titledPath;
	
	// actually write the move to an mp3 file using the path we had earlier
	if ( ![aacMovie writeToFile:titledPath withAttributes:settings] ) 
	{
		[[NSAlert unableToWriteMP3] runModal];
		NSLog(@"%@ %s - Error exporting mp3 to path %@", [self className], _cmd, titledPath);
		success = NO;
		goto mp3bail;
	}
	
	// write the tag to the mp3 file
	int status = [self tagMP3:titledPath];
	if ( status != 0 ) 
	{
		NSBeep();
		NSLog(@"%@ %s - Could not modify mp3 tags", [self className], _cmd);
	}

mp3bail:
	
	// clean up
	DisposeHandle(atomSettings);
	CloseComponent(exporter);
	[settings release];
	[aacMovie release];
	
	return success;
}

- (BOOL) addRecording:(NSString*)path toiTunes:(NSString**)savedPath error:(NSError**)anError
{
	BOOL success = YES;
	
	NSAppleEventDescriptor *appleED = nil;
	NSMutableString *mp3PathForScript = nil;
	NSString *importPreScript = nil;
	NSAppleScript *importScript = nil;
	NSError *localError = nil;
	
	NSString *importPathContents = nil;
	NSString *importPath = [[NSBundle bundleWithIdentifier:@"com.sprouted.avi"] 
			pathForResource:@"MP3AddScript" 
			ofType:@"txt"];
	
	if ( !importPath) 
	{
		[[NSAlert iTunesImportScriptUnavailable] runModal];
		NSLog(@"%@ %s - Could not locate mp3 import script", [self className], _cmd);
		goto bail;
	}
	
	mp3PathForScript = [[NSMutableString alloc] initWithString:path];
	
	NSString *playlist = [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultPlaylist"];
	if ( !playlist || [playlist length] == 0 ) playlist = @"Journler";
	
	// load the import path contents
	importPathContents = [NSString stringWithContentsOfFile:importPath usedEncoding:NULL error:&localError];
	if ( importPathContents == nil ) // force the encoding	
	{
		int i;
		NSStringEncoding encodings[2] = { NSMacOSRomanStringEncoding, NSUnicodeStringEncoding };
		
		for ( i = 0; i < 2; i++ )
		{
			importPathContents = [NSString stringWithContentsOfFile:importPath encoding:encodings[i] error:&localError];
			if ( importPathContents != nil )
				break;
		}
	}
	
	// make sure we have something with the import contents and the formatted result
	if ( importPathContents == nil || ( importPreScript = [[NSString alloc] initWithFormat:importPathContents, mp3PathForScript, playlist] ) == nil )
	{
		NSLog(@"%@ %s - unable to load importPreScript, could not determine encoding, NSUnicodeStringEncoding does not work, error: %@", 
				[self className], _cmd, localError);
		[[NSAlert iTunesImportScriptUnavailable] runModal];
	}
	else
	{
		NSDictionary *errorDict = nil;
		
		importScript = [[NSAppleScript alloc] initWithSource:importPreScript];
		appleED = [importScript executeAndReturnError:&errorDict];
		
		if ( appleED == nil && [[errorDict objectForKey:NSAppleScriptErrorNumber] intValue] != kScriptWasCancelledError )
		{
			NSLog(@"%@ %s - Could not execute mp3 import script: %@", [errorDict description]);
			
			id theSource = [importScript richTextSource];
			if ( theSource == nil ) theSource = [importScript source];
			AppleScriptAlert *scriptAlert = [[[AppleScriptAlert alloc] initWithSource:theSource error:errorDict] autorelease];
			
			NSBeep();
			[scriptAlert showWindow:self];
			
			goto bail;
		}
		else
		{
			*savedPath = [appleED stringValue];
		}
	}

bail:
	
	return success;
}

#pragma mark -

- (void) setMetadata:(NSDictionary*)metadata userLanguage:(NSString*)language forMovie:(QTMovie*)movie
{
	// keys are unsigned integer nsnumber representations of FourCharCodes
	// values must be NSStrings
	
	QTMetaDataItem	outItem;
	QTMetaDataRef   metaDataRef;
	
    Movie           theMovie;
    OSStatus        status;
	OSType			typeKey;
	
	const char *langCodeStr;
	
	theMovie = [movie quickTimeMovie];
	status = QTCopyMovieMetaData (theMovie, &metaDataRef );

	if ( status != noErr )
	{	
		NSLog(@"%@ %s - QTCopyMovieMetaData failed!", [self className], _cmd);
	}
	else
    {
		// iterate through each key
		NSNumber *aKey = nil;
		NSEnumerator *keyEnumerator = [metadata keyEnumerator];
		while ( aKey = [keyEnumerator nextObject] )
		{
			NSString *anObject = [metadata objectForKey:aKey];
			
			const char *objectPtr = [anObject UTF8String];
			typeKey = [aKey unsignedIntValue];
			
			status = QTMetaDataAddItem(metaDataRef, 
					kQTMetaDataStorageFormatQuickTime, 
					kQTMetaDataKeyFormatCommon,
					(const UInt8 *)&typeKey, 
					sizeof(typeKey), 
					(const UInt8 *)objectPtr, 
					strlen(objectPtr), 
					kQTMetaDataTypeUTF8, 
					&outItem);
			
			if ( status != noErr ) NSLog(@"%@ %s - problem adding %@ for key %@", [self className], _cmd, anObject, aKey);
		}
		
		// set the locale
		if ( language != nil && ( langCodeStr = [language cStringUsingEncoding:NSMacOSRomanStringEncoding] ) != nil )
		{
			status = QTMetaDataSetItemProperty(metaDataRef, 
					outItem, 
					kPropertyClass_MetaDataItem,
					kQTMetaDataItemPropertyID_Locale, 
					strlen(langCodeStr) + 1, 
					langCodeStr);
			
			if ( status != noErr ) NSLog(@"%@ %s - problem setting the language", [self className], _cmd);
		}
		
		// if everything went to plan update the movie file to save the metadata items that were added
		if ( status != noErr || ![movie updateMovieFile] ) NSLog(@"%@ %s - the movie's metadata could not be updated", [self className], _cmd);

		// clean up
        QTMetaDataRelease(metaDataRef);
	}
}

- (void) addMovieMetadata:(QTMovie *)aQTMovie
{
	NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
	
	static NSString *kRecordingSoftware = @"Journler";
	NSString *recordingArtist = [self recArtist];
	NSString *recordingAlbum = [self recAlbum];
	NSString *recordingTitle = [self recTitle];
	
	NSString *recordingComment = [NSString stringWithFormat:@"Recorded on %@", [[self recordingDate] description]];
	NSString *language = [self userLanguage];
	
	if ( kRecordingSoftware != nil ) [metadata setObject:kRecordingSoftware forKey:[NSNumber numberWithUnsignedInt:kQTMetaDataCommonKeySoftware]];
	if ( recordingArtist != nil ) [metadata setObject:recordingArtist forKey:[NSNumber numberWithUnsignedInt:kQTMetaDataCommonKeyArtist]];
	if ( recordingTitle != nil ) [metadata setObject:recordingTitle forKey:[NSNumber numberWithUnsignedInt:kQTMetaDataCommonKeyDisplayName]];
	if ( recordingAlbum != nil ) [metadata setObject:recordingAlbum forKey:[NSNumber numberWithUnsignedInt:kQTMetaDataCommonKeyAlbum]];
	if ( recordingComment != nil ) [metadata setObject:recordingComment forKey:[NSNumber numberWithUnsignedInt:kQTMetaDataCommonKeyComment]];

	[self setMetadata:metadata userLanguage:language forMovie:aQTMovie];
}

- (NSString*) userLanguage
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  
	NSArray *languages = [defaults objectForKey:@"AppleLanguages"];
	NSAssert(languages != NULL,@"objectForKey failed!");

	NSString *langStr = [languages objectAtIndex:0];
	return langStr;
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

#pragma mark -

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

- (NSString*) cachesFolder 
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
	return basePath;
}

- (NSString*) audioCaptureError
{
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
			
	NSString *myError = [NSString stringWithFormat:@"%@ %@", errorMessage, errorInfo];
	return myError;
}

@end
