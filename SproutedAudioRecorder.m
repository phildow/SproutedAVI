//
//  SproutedAudioRecorder.m
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


#import <SproutedAVI/SproutedAudioRecorder.h>

#import <SproutedAVI/SproutedLAMEInstaller.h>
#import <SproutedAVI/SproutedAVIAlerts.h>
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

NSString *kSproutedAudioRecordingTitleKey = @"SproutedAudioRecordingTitleKey";
NSString *kSproutedAudioRecordingAlbumKey = @"SproutedAudioRecordingAlbumKey";
//NSString *kSproutedAudioRecordingPlaylistKey = @"SproutedAudioRecordingPlaylistKey";
NSString *kSproutedAudioRecordingDateKey = @"SproutedAudioRecordingDateKey";

@implementation SproutedAudioRecorder

- (id) initWithController:(SproutedAVIController*)controller
{   
	if ( self = [super initWithController:controller] ) 
	{
		[self setRecordingDate:[NSCalendarDate calendarDate]];
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
	
	[_recordingTitle release], _recordingTitle = nil;
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
	NSLog(@"%@ %s - **** subclasses must override ****", [self className], _cmd);
	return YES;
}

- (BOOL) recorderWillLoad:(NSNotification*)aNotification
{
	NSLog(@"%@ %s - **** subclasses must override ****", [self className], _cmd);
	return YES;
}

- (BOOL) recorderDidLoad:(NSNotification*)aNotification
{
	NSLog(@"%@ %s - **** subclasses must override ****", [self className], _cmd);
	return YES;
}

- (BOOL) recorderWillClose:(NSNotification*)aNotification
{
	NSLog(@"%@ %s - **** subclasses must override ****", [self className], _cmd);
	return YES;
}

#pragma mark -

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

- (NSString*) cachesFolder 
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
	return basePath;
}

#pragma mark -

- (BOOL) setupRecording 
{
	NSLog(@"%@ %s - subclasses must override ****",[self className],_cmd);
	return NO;
}

- (BOOL) takedownRecording 
{	
	NSLog(@"%@ %s - subclasses must override ****",[self className],_cmd);
	return NO;
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

- (NSString*) recordingTitle 
{ 
	return _recordingTitle; 
}

- (void) setRecordingTitle:(NSString*)title 
{
	if ( _recordingTitle != title ) 
	{
		[self willChangeValueForKey:@"recordingTitle"];
		[_recordingTitle release];
		_recordingTitle = [title copyWithZone:[self zone]];
		[self didChangeValueForKey:@"recordingTitle"];
	}
}

- (NSString*) recordingArtist 
{ 
	NSString *theArtist = [[NSUserDefaults standardUserDefaults] stringForKey:@"DefaultArtist"];
	if ( theArtist == nil ) theArtist = [NSString string];
	return theArtist;
}

- (void) setRecordingArtist:(NSString*)artist 
{
	[self willChangeValueForKey:@"recordingArtist"];
	[[NSUserDefaults standardUserDefaults] setObject:artist forKey:@"DefaultArtist"];
	[self didChangeValueForKey:@"recordingArtist"];
}

- (NSString*) recordingAlbum 
{ 
	NSString *theAlbum = [[NSUserDefaults standardUserDefaults] stringForKey:@"DefaultAlbum"];
	if ( theAlbum == nil ) theAlbum = [NSString string];
	return theAlbum;
}

- (void) setRecordingAlbum:(NSString*)album 
{
	[self willChangeValueForKey:@"recordingAlbum"];
	[[NSUserDefaults standardUserDefaults] setObject:album forKey:@"DefaultAlbum"];
	[self didChangeValueForKey:@"recordingAlbum"];
}

- (NSCalendarDate*) recordingDate
{ 
	return _recordingDate; 
}

- (void) setRecordingDate:(NSCalendarDate*)aDate 
{
	if ( _recordingDate != aDate ) 
	{
		[self willChangeValueForKey:@"recordingDate"];
		[_recordingDate release];
		_recordingDate = [aDate copyWithZone:[self zone]];
		[self didChangeValueForKey:@"recordingDate"];
	}
}

#pragma mark -

- (void) setRecordingAttributes:(NSDictionary*)aDictionary
{
	//kSproutedAudioRecordingTitleKey
	//kSproutedAudioRecordingAlbumKey
	//kSproutedAudioRecordingPlaylistKey
	//kSproutedAudioRecordingDateKey
	
	NSString *aTitle = [aDictionary objectForKey:kSproutedAudioRecordingTitleKey];
	if ( aTitle != nil ) [self setRecordingTitle:aTitle];
	
	NSString *anAlbum = [aDictionary objectForKey:kSproutedAudioRecordingAlbumKey];
	if ( anAlbum != nil ) [self setRecordingAlbum:anAlbum];
	
	NSCalendarDate *theDate = [aDictionary objectForKey:kSproutedAudioRecordingDateKey];
	if ( theDate != nil ) [self setRecordingDate:theDate];
}

#pragma mark -

- (IBAction)setChannelGain:(id)sender
{
	NSLog(@"%@ %s - **** subclasses must override ****",[self className],_cmd);
}

#pragma mark -

- (IBAction)recordPause:(id)sender
{
	if ( _recording )
	{
		[self stopRecording:sender];
		
		// update the view and release no longer needed information
		[self prepareForPlaying];
		
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
	}
}

- (IBAction) stopRecording:(id)sender
{
	NSLog(@"%@ %s - **** subclasses must override ****",[self className],_cmd);
}

- (IBAction) startRecording:(id)sender
{
	NSLog(@"%@ %s - **** subclasses must override ****",[self className],_cmd);
}

#pragma mark -

- (void) prepareForPlaying 
{	
	NSLog(@"%@ %s - **** subclasses must override ****",[self className],_cmd);
}

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
	[self playlockCallback:self];
	
	_playingMovie = NO;
}

- (IBAction) rewind:(id)sender {

	[player stepBackward:self];
	[recordButton setState:NSOffState];
	[self playlockCallback:self];
	
	_playingMovie = NO;
}

#pragma mark -

- (void) playlockCallback:(id)object 
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
	
	[tag setTitle:[self recordingTitle]];
	[tag setAlbum:[self recordingAlbum]];
	[tag setArtist:[self recordingArtist]];
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
			stringByAppendingPathComponent:[[self recordingTitle] pathSafeString]] 
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
			stringByAppendingPathComponent:[[self recordingTitle] pathSafeString]] 
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

- (IBAction) insert:(id)sender 
{		
	[self saveRecording:sender];
}

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
		[theTarget sproutedAudioRecorder:self insertRecording:finishedFileLoc title:[self recordingTitle]];
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

#pragma mark -
#pragma mark Movie Tagging

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

// Add the artist, title, album and other metadata to the movie file
- (void) addMovieMetadata:(QTMovie *)aQTMovie
{
	NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
	
	static NSString *kRecordingSoftware = @"Sprouted AVI";
	NSString *recordingArtist = [self recordingArtist];
	NSString *recordingAlbum = [self recordingAlbum];
	NSString *recordingTitle = [self recordingTitle];
	
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
#pragma mark File Manager Delegation

- (void)fileManager:(NSFileManager *)manager willProcessPath:(NSString *)path 
{
	// simply for the sake of consistency
}

- (BOOL)fileManager:(NSFileManager *)manager shouldProceedAfterError:(NSDictionary *)errorInfo 
{
	// log the error and return no
	
	NSLog(@"%@ %s -  \nEncountered file manager error: source = %@, error = %@, destination = %@\n",
			[errorInfo objectForKey:@"Path"], 
			[errorInfo objectForKey:@"Error"], 
			[errorInfo objectForKey:@"ToPath"],
			[self className], _cmd);
	
	return NO;
}

@end