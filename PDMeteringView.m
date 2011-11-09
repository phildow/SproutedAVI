//
//  PDMeteringView.m
//  VideoCapturePlugin
//
//  Created by Philip Dow on 1/18/06.
//  Copyright Philip Dow / Sprouted. All rights reserved.
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


#import <SproutedAVI/PDMeteringView.h>

extern double dbamp(double db);
extern ampdb(double amp);

#define kMinBarGap 			3
#define kBarHeight  		8
#define kBarInteriorHeight 	9
#define kClipBoxWidth		6

@implementation PDMeteringView

- (id)initWithFrame:(NSRect)frame 
{
	if ( self = [super initWithFrame:frame] ) 
	{
		NSBundle *myBundle = [NSBundle bundleWithIdentifier:@"com.sprouted.avi"];
		
		meterImage = [[NSImage alloc] initWithContentsOfFile:[myBundle pathForImageResource:@"metering"]];
		borderColor = [[NSColor colorWithCalibratedRed:142./255. green:146./255. blue:121./255. alpha:1.0] retain];		
	}
	return self;
}

- (void) dealloc {
	
	[meterImage release];
	[borderColor release];
	
	[super dealloc];
	
}

- (void)drawRect:(NSRect)rect {
#pragma unused(rect)
    // Drawing code here.
	
	NSRect barRect = [self bounds];
	NSRect border = NSMakeRect(0,barRect.size.height/2-4, barRect.size.width,8);
	
	if ( mMeterValues ) {
	
		float value = roundf(mMeterValues[0 * 2]);
		barRect.size.width = value;
		
		//if ( !drawsMetersOnly )
		[meterImage drawInRect:barRect fromRect:barRect operation:NSCompositeSourceOver fraction:1.0];
	
	}
	
	[borderColor set];
	NSFrameRect(border);
	
	drawsMetersOnly = NO;
}

- (void) setNumChannels: (int) num {
	if (mNumChannels != num) {
		mNumChannels = num;
		if (mMeterValues != nil)
			free(mMeterValues);
		if (mOldMeterValues != nil)
			free(mOldMeterValues);
		if (mClipValues != nil)
			free(mClipValues);
		mMeterValues = (float *) calloc (2 * num, sizeof(float));
		mOldMeterValues = (float *) calloc (2 * num, sizeof(float));
		mClipValues = (int *) calloc (num, sizeof(int));
		drawsMetersOnly = NO;
		
		firstTrackOffset = floorf(([self bounds].size.height - (num * kBarHeight + (num-1) * kMinBarGap))/2);
		[self setNeedsDisplay: YES];
	}
}

- (void) updateMeters: (float *) meterValues {
	int i;
	
	if (![self inLiveResize]) {
		int numItems = mNumChannels * 2;
		for (i = 0; i < numItems; i++) {
			float tempValue = dbamp(meterValues[i]); 
			mOldMeterValues[i] = mMeterValues[i];
			float pixelValue = [self pixelForValue: tempValue inSize: (int) [self bounds].size.width];
			float top = [self bounds].size.width - (mHasClip ? kClipBoxWidth + 4: 2);
			if (pixelValue < 0)
				pixelValue = 0;
			else if (pixelValue > top)
				pixelValue = top;
				
			mMeterValues[i] = pixelValue;
			if (mHasClip) {
				if (tempValue > mMaxValue)
					mClipValues[i] = 1;
			}		
		}
		drawsMetersOnly = YES;
		[self setNeedsDisplay: YES];
	}
}

- (void)mouseDown:(NSEvent *)theEvent
{
	if (mHasClip) {
		int i;
		float yOffset = .5 + firstTrackOffset;
		float topGap  = mHasClip ? kClipBoxWidth + 3: 0;

		NSRect clipRect = NSMakeRect([self bounds].size.width - topGap, 0, kClipBoxWidth + 3, kBarHeight-2);
		NSPoint mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
		
		for (i = 0; i < mNumChannels; i++) {
			clipRect.origin.y = yOffset + .5;
			if ([self mouse:mouseLoc inRect: clipRect]) {
				mClipValues[i] = 0;
				break;
			}
			yOffset += kMinBarGap + kBarHeight;
		}
	}
	drawsMetersOnly = NO;
	[self setNeedsDisplay: YES];
}

- (BOOL) acceptsFirstMouse: (NSEvent *) event {
#pragma unused(event)
    return YES;
}


- (BOOL) isOpaque {
	return NO;
}

@end
