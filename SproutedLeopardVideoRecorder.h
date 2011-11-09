//
//  SproutedLeopardVideoRecorder.h
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


#import <Cocoa/Cocoa.h>
#import <QTKit/QTkit.h>
#import <Carbon/Carbon.h>
#import <SproutedAVI/SproutedRecorder.h>

@interface SproutedLeopardVideoRecorder : SproutedRecorder {
	
	IBOutlet QTCaptureView *mCaptureView;
	IBOutlet NSLevelIndicator *mAudioLevelMeter;
	IBOutlet NSSlider *mVolumeSlider;
	IBOutlet NSTextField *mTimeField;
	IBOutlet NSTextField *mSizeField;
	
	IBOutlet NSButton *mRecordPauseButton;
	IBOutlet NSButton *mFastforwardButton;
	IBOutlet NSButton *mRewindButton;
	IBOutlet NSButton *mInsertButton;
	IBOutlet NSImageView *mVolumeImage;
	
	IBOutlet QTMovieView *mPlayer;
	IBOutlet NSView *mPlaybackHolder;
	IBOutlet NSSlider *mPlaybackLocSlider;
    
    QTCaptureSession            *mCaptureSession;
    QTCaptureMovieFileOutput    *mCaptureMovieFileOutput;
    QTCaptureDeviceInput        *mCaptureVideoDeviceInput;
    QTCaptureDeviceInput        *mCaptureAudioDeviceInput;
	
	NSString *mMoviePath;
	NSTimer *mAudioLevelTimer;
	NSTimer *mUpdatePlaybackLocTimer;
	
	BOOL mRecording;
	BOOL mPlayingMovie;
	BOOL mUnsavedRecording;
	
	EventTime mRecordingStart;
}

- (NSString*) videoCaptureError;

- (IBAction) recordPause:(id)sender;
- (IBAction) startRecording:(id)sender;
- (IBAction) stopRecording:(id)sender;

- (IBAction) saveRecording:(id)sender;

- (void) takedownRecording;
- (void) prepareForPlaying;

- (IBAction) changePlaybackVolume:(id)sender;
- (IBAction) changePlaybackLocation:(id)sender;

- (IBAction) fastForward:(id)sender; 
- (IBAction) rewind:(id)sender;

- (void) updateAudioLevels:(NSTimer *)aTimer;
- (void) updateTimeAndSizeDisplay:(NSTimer*)aTimer;

- (NSImage*) volumeImage:(float)volume minimumVolume:(float)minimum;

@end

@interface NSObject (SproutedLeopardVideoRecorderTarget)

- (void) sproutedVideoRecorder:(SproutedRecorder*)recorder insertRecording:(NSString*)path title:(NSString*)title;

@end
