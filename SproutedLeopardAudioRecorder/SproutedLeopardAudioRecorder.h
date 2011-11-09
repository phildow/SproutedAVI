//
//  SproutedLeopardAudioRecorder.h
//  Sprouted AVI
//
//  Created by Philip Dow on 5/1/08.
//  Copyright 2008 Lead Developer, Journler Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QTKit/QTkit.h>
#import <ID3/TagAPI.h>
#import <SproutedUtilities/SproutedUtilities.h>
#import <SproutedInterface/SproutedInterface.h>
#import <SproutedAVI/SproutedRecorder.h>

@class SproutedLAMEInstaller;
@class PDMovieSlider;

@interface SproutedLeopardAudioRecorder : SproutedRecorder {
	
	// main recording window
	IBOutlet NSTextField *recTitleField;
	IBOutlet NSTextField *recArtistField;
	IBOutlet NSTextField *recAlbumField;
	
	IBOutlet NSButton *insertButton;
	IBOutlet NSButton *recordButton;
	
	IBOutlet NSLevelIndicator *mAudioLevelMeter;
	IBOutlet NSTextField *timeField;
	IBOutlet NSTextField *sizeField;
	
	IBOutlet NSSlider *volumeSlider;
	IBOutlet NSImageView *volumeImage;
	
	IBOutlet QTMovieView *player;
	IBOutlet NSButton *fastforward;
	IBOutlet NSButton *rewind;
	IBOutlet PDMovieSlider *playbackLocSlider;
	
	//and for the notifications during convert
	IBOutlet NSWindow *recProgressWin;
	IBOutlet NSTextField *recProgressText;
	IBOutlet NSProgressIndicator *recProgress;
	
	IBOutlet NSView *playbackLockHolder;
	IBOutlet NSObjectController *recorderController;
	
	// QTKit capture session
	QTCaptureSession *mCaptureSession;
    QTCaptureMovieFileOutput *mCaptureMovieFileOutput;
	QTCaptureDeviceInput *mCaptureAudioDeviceInput;
	
	// additional variables
	EventTime _recordingStart;
	BOOL _recording;
	BOOL _unsavedRecording;
	
	NSTimer	*mAudioLevelTimer;
	NSTimer	*idleTimer;
	NSTimer	*updatePlaybackLocTimer;
	
	NSString *_recTitle;
	NSString *_recArtist;
	NSString *_recAlbum;
	
	NSCalendarDate *_recordingDate;
	
	NSString *movPath;
	NSString *mp3Path;
	
	BOOL recordingDisabled;
	BOOL _playingMovie;
	BOOL _sequenceComponentsClosed;
	
	BOOL convertToMp3;
	NSInteger saveAction;
}

- (NSString*) recTitle;
- (void) setRecTitle:(NSString*)title;

- (NSString*) recArtist;
- (void) setRecArtist:(NSString*)artist;

- (NSString*) recAlbum;
- (void) setRecAlbum:(NSString*)album;

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
- (void) prepareForPlaying;

// making the recording

- (IBAction) recordPause:(id)sender;
- (IBAction) startRecording:(id)sender;
- (IBAction) setChannelGain:(id)sender;

// playing the recording

- (IBAction) playPause:(id)sender;
- (IBAction) changePlaybackVolume:(id)sender;
- (IBAction) changePlaybackLocation:(id)sender;
- (void) playlockCallback:(NSTimer*)aTimer;

- (IBAction) fastForward:(id)sender;
- (IBAction) rewind:(id)sender;

// saving the recording

- (IBAction) saveRecording:(id)sender;
- (BOOL) prepareRecording:(NSString*)path asMovie:(NSString**)savedPath error:(NSError**)anError;
- (BOOL) prepareRecording:(NSString*)path asMP3:(NSString**)savedPath error:(NSError**)anError;
- (BOOL) addRecording:(NSString*)path toiTunes:(NSString**)savedPath error:(NSError**)anError;
- (Component) lameMP3ConverterComponent;
- (int) tagMP3:(NSString*)path;


- (void) setMetadata:(NSDictionary*)metadata userLanguage:(NSString*)language forMovie:(QTMovie*)movie;
- (void) addMovieMetadata:(QTMovie *)aQTMovie;
- (NSString*) userLanguage;

- (void) updateAudioLevels:(NSTimer *)aTimer;
- (void) updateTimeAndSizeDisplay:(NSTimer*)aTimer;

- (NSImage*) volumeImage:(float)volume minimumVolume:(float)minimum;
- (NSString*) cachesFolder;
- (NSString*) audioCaptureError;

@end
