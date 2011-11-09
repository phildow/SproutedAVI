//
//  SproutedAudioRecorder.h
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


#import <Cocoa/Cocoa.h>
#import <QTKit/QTKit.h>
#import <ID3/TagAPI.h>
#import <SproutedUtilities/SproutedUtilities.h>
#import <SproutedInterface/SproutedInterface.h>

#import <SproutedAVI/SproutedRecorder.h>

@class SeqGrab;
@class SproutedLAMEInstaller;
@class PDMeteringView;
@class PDMovieSlider;

typedef enum {
	kSproutedAudioSavedToiTunes = 1,
	kSproutedAudioSavedToTemporaryLocation = 2
} SproutedAudioSaveAction;

extern NSString *kSproutedAudioRecordingTitleKey;
extern NSString *kSproutedAudioRecordingAlbumKey;
//extern NSString *kSproutedAudioRecordingPlaylistKey;
extern NSString *kSproutedAudioRecordingDateKey;

@interface SproutedAudioRecorder : SproutedRecorder
{
	// main recording window
	IBOutlet NSTextField			*recTitleField;
	IBOutlet NSTextField			*recArtistField;
	IBOutlet NSTextField			*recAlbumField;
	IBOutlet NSButton				*insertButton;
	IBOutlet NSButton				*recordButton;
	
	IBOutlet	NSTextField			*timeField;
	IBOutlet	NSSlider			*volumeSlider;
	IBOutlet	NSImageView			*volumeImage;
	IBOutlet	QTMovieView			*player;
	IBOutlet	NSButton			*fastforward;
	IBOutlet	NSButton			*rewind;
	IBOutlet	PDMovieSlider		*playbackLocSlider;
	
	//and for the notifications during convert
	IBOutlet NSWindow				*recProgressWin;
	IBOutlet NSTextField			*recProgressText;
	IBOutlet NSProgressIndicator	*recProgress;
	
	IBOutlet NSView *playbackLockHolder;
	IBOutlet NSObjectController		*recorderController;
	
	EventTime			_recordingStart;
	BOOL				_recording;
	BOOL _unsavedRecording;
	
	NSTimer				*mUpdateMeterTimer;
	NSTimer				*idleTimer;
	NSTimer				*updatePlaybackLocTimer;
	
	NSString			*_recordingTitle;	
	NSCalendarDate		*_recordingDate;
	
	NSString			*movPath;
	NSString			*mp3Path;
	
	BOOL				recordingDisabled;
	BOOL				_playingMovie;
	BOOL				_sequenceComponentsClosed;
	
	BOOL convertToMp3;
	NSInteger saveAction;	
}

- (void) setRecordingAttributes:(NSDictionary*)aDictionary;

- (NSString*) recordingTitle;
- (void) setRecordingTitle:(NSString*)title;

- (NSString*) recordingArtist;
- (void) setRecordingArtist:(NSString*)artist;

- (NSString*) recordingAlbum;
- (void) setRecordingAlbum:(NSString*)album;

- (NSCalendarDate*) recordingDate;
- (void) setRecordingDate:(NSCalendarDate*)aDate;

- (BOOL) recordingDisabled;
- (void) setRecordingDisabled:(BOOL)disabled;

- (int) saveAction;
- (void) setPathTitle:(NSString*)aString;

- (NSString*) movPath;
- (void) setMovPath:(NSString*)path;

- (NSString*) mp3Path;
- (void) setMp3Path:(NSString*)path;

- (BOOL) setupRecording;
- (BOOL) takedownRecording;

- (IBAction) recordPause:(id)sender;
- (IBAction) startRecording:(id)sender;

- (IBAction) changePlaybackLocation:(id)sender;
- (IBAction) changePlaybackVolume:(id)sender;
- (IBAction) setChannelGain:(id)sender;

- (void) prepareForPlaying;

- (void) playlockCallback:(id)object;
- (void) movieEnded:(NSNotification*)aNotification;

- (IBAction) fastForward:(id)sender;
- (IBAction) rewind:(id)sender;

- (IBAction) insert:(id)sender;

- (int) tagMP3:(NSString*)path;
- (Component) lameMP3ConverterComponent;

- (BOOL) prepareRecording:(NSString*)path asMovie:(NSString**)savedPath error:(NSError**)anError;
- (BOOL) prepareRecording:(NSString*)path asMP3:(NSString**)savedPath error:(NSError**)anError;
- (BOOL) addRecording:(NSString*)path toiTunes:(NSString**)savedPath error:(NSError**)anError;

- (void) addMovieMetadata:(QTMovie *)aQTMovie;
- (void) setMetadata:(NSDictionary*)metadata userLanguage:(NSString*)language forMovie:(QTMovie*)movie;

- (NSString*) userLanguage;

- (NSImage*) volumeImage:(float)volume minimumVolume:(float)minimum;
- (NSString*) cachesFolder;
- (NSString*) audioCaptureError;

@end

@interface NSObject (SproutedAudioRecorderTarget)

- (void) sproutedAudioRecorder:(SproutedRecorder*)recorder insertRecording:(NSString*)path title:(NSString*)title;

@end
