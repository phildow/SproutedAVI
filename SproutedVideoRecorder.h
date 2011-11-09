//
//  SproutedVideoRecorder.h
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
#import <Carbon/Carbon.h>
#import <QuartzCore/QuartzCore.h>
#import <QuickTime/QuickTime.h>
#import <QTKit/QTKit.h>

#import <SproutedAVI/SproutedRecorder.h>

@class PDMeteringView;

typedef struct {
	
	/* general items */
	Movie						outputMovie;					// recorded movie
	SeqGrabComponent			seqGrab;						// sequence grabber
	DataHandler					outputMovieDataHandler;			// movie header storage
	
	/* movie items */
	Media						videoMedia;						// the movie's video track
	SGChannel					videoChan;						// sequence grabber video channel
	
	/* audio items */
	Media						soundMedia;						// the movie's sound track
	SGChannel					audioChan;						// the sequence grabber audio channel
	
	BOOL						recording;						// recording or previewing?
	
	long						length;
	
	CGContextRef				graphicsContext;				// graphics context (window)
	CGColorSpaceRef				colorspace;						// graphics colorspace
	
	CGRect						targetRect;						// target rect within graphics context
	TimeScale					timeScale;
	
	/* deciding to drop a frame */
	Boolean						dropFrame;
	float						mDesiredPreviewFrameRate;
	TimeValue                   mMinPreviewFrameDuration;
	CodecQ						previewQuality;
	
	Boolean						didBeginVideoMediaEdits;
	int							width;
	int							height;
	CodecType					codecType;
	SInt32						averageDataRate;
	
	ICMDecompressionSessionRef	decompressionSession;
	ICMCompressionSessionRef	compressionSession;
	
	Boolean						verbose;
    TimeValue					lastTime;
	int							desiredFramesPerSecond;
	TimeValue					minimumFrameDuration;
    long						frameCount;
    Boolean						isGrabbing;
	
	Boolean						didBeginSoundMediaEdits;
	TimeScale                   audioTimeScale;
	SoundDescriptionHandle      audioDescH;
	AudioStreamBasicDescription asbd;
	
} PDCaptureRecord, *PDCaptureRecordPtr;

@interface SproutedVideoRecorder : SproutedRecorder
{
	
	IBOutlet NSView *previewPlaceholder;
	IBOutlet PDMeteringView *mMeteringView;
	
	IBOutlet NSTextField *timeField;
	IBOutlet NSTextField *sizeField;
	
	IBOutlet NSImageView *volumeImage;
	IBOutlet NSSlider *volumeSlider;
	IBOutlet NSButton *mRecordPauseButton;
	IBOutlet NSSlider *playbackLocSlider;
	
	IBOutlet NSButton *fastforward;
	IBOutlet NSButton *rewind;
	
	IBOutlet NSView *playbackHolder;
	IBOutlet QTMovieView *player;
	
	int							_encodingOption;				// currently supports two: 0 = MPEG4, 1 = H264
	CodecQ						_mPreviewQuality;
	float						_previewFrameRate;
	NSString					*_moviePath;
	
	// for the metering
	NSTimer						*idleTimer;
	NSTimer						*mUpdateMeterTimer;				// will double as a seconds display
	NSTimer						*updatePlaybackLocTimer;
	QTMLMutex                   mMutex;
	
	EventTime					_recordingStart;
	
	BOOL _unsavedRecording;
	BOOL						_playingMovie;
	
	UInt32                      mChannelNumber;
	Float32 *                   mLevelsArray;
	UInt32						mMyIndex;
	UInt32                      mLevelsArraySize;
	
	// data structure passed to sequence grabber callbacks
	PDCaptureRecordPtr	captureData;
	
	BOOL _prepped;
	BOOL _preppedForPlaying;
	
	// changes for the plugin
	IBOutlet NSButton *insertButton;

	BOOL _inserted;
	BOOL _alreadyPrepared;
	
}

- (int) encodingOption;
- (void) setEncodingOption:(int)option;

- (void)setPreviewQuality:(CodecQ)quality;
- (CodecQ)previewQuality;

- (float) previewFrameRate;
- (void) setPreviewFrameRate:(float)rate;

- (NSString*) moviePath;
- (void) setMoviePath:(NSString*)path;


- (BOOL) inserted;
- (BOOL) prepareForRecording;


- (OSErr) _initDataAndProc;
- (OSErr) _prepareCaptureData;
- (OSErr) finishOutputMovie;

- (BOOL)_addVideoTrack;
- (BOOL)_addAudioTrack;

- (void) meterTimerCallback:(id)object;
- (void) updateChannelLevel;

- (IBAction)recordPause:(id)sender;
- (IBAction)stop:(id)sender;

- (BOOL) takedownRecording;

- (IBAction) prepareForPlaying:(id)sender;
- (IBAction) playPause:(id)sender;
- (IBAction) changePlaybackVolume:(id)sender;
- (IBAction) changePlaybackLocation:(id)sender;

- (IBAction) fastForward:(id)sender;
- (IBAction) rewind:(id)sender;

- (void) playlockCallback:(id)object;
	
- (void)idleTimer:(NSTimer*)timer;

- (IBAction)setChannelGain:(id)sender;

- (NSImage*) volumeImage:(float)volume minimumVolume:(float)minimum;

- (IBAction) insertEntry:(id)sender;

- (NSString*) videoCaptureError;

@end

@interface NSObject (SproutedVideoRecorderTarget)

- (void) sproutedVideoRecorder:(SproutedRecorder*)recorder insertRecording:(NSString*)path title:(NSString*)title;

@end
