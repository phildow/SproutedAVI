//
//  SproutedTigerAudioRecorder.h
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


#import <Cocoa/Cocoa.h>
#import <QTKit/QTKit.h>
#import <SproutedAVI/SproutedAudioRecorder.h>

@interface SproutedTigerAudioRecorder : SproutedAudioRecorder {
	
	IBOutlet	PDMeteringView		*mMeteringView;
	
	// the quicktime recording items
	SeqGrab				*mGrabber;
	SeqGrabComponent	seqGrab;
	SGChannel			audioChan;
	
	QTMLMutex			mMutex;
	UInt32				mLevelsArraySize;
	Float32 *			mLevelsArray;
	UInt32				mChannelNumber;
	UInt32				mMyIndex;
}

- (BOOL) _addAudioTrack;
- (IBAction) togglePlaythru:(id)sender;
- (OSStatus)setCapturePath:(NSString *)path flags:(long)flags;

- (void) idleTimerCallback:(NSTimer*)timer;
- (void) meterTimerCallback:(NSTimer*)timer;
- (void) updateTimer;
- (void) updateChannelLevel;

@end
