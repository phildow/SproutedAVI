//
//  SproutedSnapshot.m
//  Journler
//
//  Created by Philip Dow on 11/6/06.
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


#import <SproutedAVI/SproutedSnapshot.h>
#import <SproutedAVI/SproutedAVIAlerts.h>
#import <SproutedAVI/CSGCamera.h>
#import <SproutedAVI/CSGImage.h>

@implementation SproutedSnapshot

- (id) initWithController:(SproutedAVIController*)controller
{
	if ( self = [super initWithController:controller] )
	{
		currentSlot = slotsTaken = 0;
		[NSBundle loadNibNamed:@"Snapshot" owner:self];
	}
	return self;
}

- (void) dealloc
{
	[shutterSound release], shutterSound = nil;
	[countdownSound release], countdownSound = nil;
	[selectionIndexes release], selectionIndexes = nil;
	[images release], images = nil;
	[camera release], camera = nil;
	
	[photosArrayController release], photosArrayController = nil;
	
	if ( snapshotTimer != nil )
	{
		[snapshotTimer invalidate];
		[snapshotTimer release], snapshotTimer = nil;
	}
	
	[super dealloc];
}

#pragma mark -

- (BOOL) recorderShouldClose:(NSNotification*)aNotification error:(NSError**)anError
{
	return YES;
}

- (BOOL) recorderWillLoad:(NSNotification*)aNotification
{
	// runtime security check prevents subclassing
	if ( ![self isMemberOfClass:[SproutedSnapshot class]] )
		return NO;
	
	NSBundle *myBundle = [NSBundle bundleWithIdentifier:@"com.sprouted.avi"];
	
	// sounds
	countdownSound = [[NSSound soundNamed:@"Hero"] retain];
	shutterSound = [[NSSound alloc] initWithContentsOfFile:[myBundle pathForSoundResource:@"photo_shutter.aiff"] byReference:YES];
	
	MUPhotoCell *photoCell = [[[MUPhotoCell alloc] initImageCell:nil] autorelease];
	[photoCell setImageFrameStyle:NSImageFrameNone];
	[photoCell setImageScaling:NSScaleProportionally];
	
	[photoCell setAlignment:NSCenterTextAlignment];
	[photoCell setImageAlignment:NSImageAlignTop];
	
	[photoCell setBezeled:NO];
	[photoCell setBordered:YES];
	
	[photoView setCell:photoCell];
	
	[photoView setBackgroundColor:[NSColor colorWithCalibratedWhite:0.92 alpha:1.0]];
	[photoView setUseOutlineBorder:NO];
	
	[photoView setSelectionBorderColor:[NSColor darkGrayColor]];
	[photoView setSelectionBorderWidth:2];
	
	[photoView setPhotoSize:64];
	[photoView setPhotoHorizontalSpacing:0];
	
	// UnknownFSObjectIcon
	NSImage *placeholder = [[[NSImage alloc] initWithContentsOfFile:[myBundle pathForImageResource:@"UnknownFSObjectIcon.icns"]] autorelease];
	
	NSImage *holder1 = [[placeholder copyWithZone:[self zone]] autorelease];
	NSImage *holder2 = [[placeholder copyWithZone:[self zone]] autorelease];
	NSImage *holder3 = [[placeholder copyWithZone:[self zone]] autorelease];
	NSImage *holder4 = [[placeholder copyWithZone:[self zone]] autorelease];
		
	NSArray *theImages = [NSArray arrayWithObjects:holder1, holder2, holder3, holder4, nil];
	[self setImages:theImages];

	[photoView bind:@"photosArray" toObject:photosArrayController withKeyPath:@"arrangedObjects" options:nil];
    [photoView bind:@"selectedPhotoIndexes" toObject:photosArrayController withKeyPath:@"selectionIndexes" options:nil];
	
	return YES;
}	

- (BOOL) recorderDidLoad:(NSNotification*)aNotification
{	
	// Start recording
	camera = [[CSGCamera alloc] init];
	[camera setDelegate:self];
	
	if ( ![camera startWithSize:NSMakeSize(640, 480)] )
	{
		// error initializing the capture
		capturing = NO;
		
		NSString *errorMessage = NSLocalizedStringFromTableInBundle(
				@"no snapshot capture msg", 
				@"Localizable", 
				[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
				@"");
		NSString *errorInfo = NSLocalizedStringFromTableInBundle(
				@"no snapshot capture info", 
				@"Localizable", 
				[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
				@"");
				
		NSString *myError = [NSString stringWithFormat:@"%@\n\n%@", errorMessage, errorInfo];
		[self setError:myError];
	}
	else
	{
		capturing = YES;
	}
	
	return capturing;
}

- (BOOL) recorderWillClose:(NSNotification*)aNotification
{
	if ( capturing ) 
	{
		[camera stop];
		capturing = NO;
	}
	
	[photoView unbind:@"photosArray"];
	[photoView unbind:@"selectedPhotoIndexes"];
	[photoView ownerWillClose:nil];
	
	[photosArrayController unbind:@"contentArray"];
	[photosArrayController setContent:nil];
	
	if ( snapshotTimer != nil )
	{
		[snapshotTimer invalidate];
		[snapshotTimer release], snapshotTimer = nil;
	}
	
	[camera setDelegate:nil];
	
	return YES;
}

#pragma mark -

- (NSArray*) images
{
	return images;
}

- (void) setImages:(NSArray*)anArray
{
	if ( images != anArray )
	{
		[images release];
		images = [anArray retain];
	}
}

- (NSIndexSet*) selectionIndexes
{
	return selectionIndexes;
}

- (void) setSelectionIndexes:(NSIndexSet*)anIndexSet
{
	if ( selectionIndexes != anIndexSet )
	{
		[selectionIndexes release];
		selectionIndexes = [anIndexSet copyWithZone:[self zone]];
	}
}

#pragma mark -
#pragma mark CSGCamera Delegate

- (void)camera:(CSGCamera *)aCamera didReceiveFrame:(CSGImage *)aFrame;
{
	[cameraView setImage:aFrame];
}

#pragma mark -
#pragma mark Photo View Delegation

- (unsigned)photoCountForPhotoView:(MUPhotoView *)view
{
    return [images count];
}

- (NSImage *)photoView:(MUPhotoView *)view photoAtIndex:(unsigned)index
{
    return [images objectAtIndex:index];
}

- (NSIndexSet *)selectionIndexesForPhotoView:(MUPhotoView *)view;
{
    return selectionIndexes;
}

- (NSIndexSet *)photoView:(MUPhotoView *)view willSetSelectionIndexes:(NSIndexSet *)indexes
{
	// prevent multiple selection
	// do not allow selection of empty image slots
	
	int theFirstIndex = [indexes firstIndex];
	if ( theFirstIndex >= slotsTaken )
		return [NSIndexSet indexSet];
	else
		return [NSIndexSet indexSetWithIndex:theFirstIndex];
}

- (void)photoView:(MUPhotoView *)view didSetSelectionIndexes:(NSIndexSet *)indexes
{
    [self setSelectionIndexes:indexes];
}


- (void)photoView:(MUPhotoView *)view doubleClickOnPhotoAtIndex:(unsigned)index withFrame:(NSRect)frame
{
    // the example is wrong, doesn't include withFrame portion
	
	if ( index >= [[photosArrayController arrangedObjects] count] )
		NSLog(@"%@ %s - index %i beyond bounds %i", [self className], _cmd, index, [[photosArrayController arrangedObjects] count]);
	
	NSImage *thePhoto = [[photosArrayController arrangedObjects] objectAtIndex:index];
	if ( thePhoto != nil )
	{
		if ( capturing ) 
		{
			[camera stop];
			capturing = NO;
		}

		[cameraView setImage:thePhoto];
		[resetButton setHidden:NO];
	}
}

- (NSString*) photoView:(MUPhotoView*)photoView titleForObjectAtIndex:(unsigned int)index
{
	return nil;
}


#pragma mark -

- (IBAction) takeSnapshot:(id)sender
{
	if ( capturing == NO )
	{
		[resetButton setHidden:YES];
		if ( ![camera startWithSize:NSMakeSize(640, 480)] )
		{
			// error initializing the capture
			[[NSAlert snapshotUnavailable] runModal];
			[insertButton setEnabled:NO];
			[takeButton setEnabled:NO];
			capturing = NO;
		}
		else
		{
			capturing = YES;
		}
	}
	else
	{
		capturing = YES;
	}
	
	[takeButton setEnabled:NO];
	
	snapshotTimer = [[NSTimer scheduledTimerWithTimeInterval:0.8 
			target:self 
			selector:@selector(_snapshotCountdown:) 
			userInfo:nil 
			repeats:YES] retain];
	
	countdown = 3;
	[coundownField setStringValue:@"3"];
	[coundownField setHidden:NO];
	[snapshotTimer fire];
}

- (IBAction) reset:(id)sender
{	
	[self performSelector:@selector(_reset:) withObject:nil afterDelay:0.05];
}

- (void) _reset:(id)anObject
{
	[resetButton setHidden:YES];
	
	if ( ![camera startWithSize:NSMakeSize(640, 480)] )
	{
		// error initializing the capture
		[[NSAlert snapshotUnavailable] runModal];
		[insertButton setEnabled:NO];
		[takeButton setEnabled:NO];
		capturing = NO;
	}
	else
	{
		capturing = YES;
		[takeButton setEnabled:YES];
	}
}

- (IBAction) save:(id)sender
{
	[self saveRecording:sender];
}

- (IBAction) stopRecording:(id)sender
{
	// nothing to do
	return;
}

- (IBAction) saveRecording:(id)sender
{
	// save the image to a temp directory
	NSString *dateTime = [[NSDate date] descriptionWithCalendarFormat:@"%H%M%S" timeZone:nil locale:nil];
	NSString *tempDir = NSTemporaryDirectory();
	if ( tempDir == nil ) tempDir = [NSString stringWithString:@"/tmp"];
	
	NSIndexSet *theSelection = [photoView selectedPhotoIndexes];
	if ( [theSelection count] == 0 )
	{
		NSBeep(); return;
	}
	
	NSImage *theImage = [images objectAtIndex:[theSelection firstIndex]];
	NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithData:[theImage TIFFRepresentation]];
	
	NSString *formatString = @"png";
	NSBitmapImageFileType fileType = NSPNGFileType;
		
	NSString *path = [[NSString alloc] initWithString:[tempDir stringByAppendingPathComponent:
			[NSString stringWithFormat:@"%@ Snapshot.%@", dateTime, formatString]]];
	
	NSData *pngData = [bitmapRep representationUsingType:fileType 
			properties:[NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:1.0] 
					forKey:NSImageCompressionFactor]];
	
	if ( pngData == nil )
	{
		NSLog(@"%@ %s - unable to derive png data for image", [self className], _cmd);
		NSBeep(); return;
	}
	
	NSError *writeError;
	if ( ![pngData writeToFile:path options:0 error:&writeError] )
	{
		NSLog(@"%@ %s - unable to write png data to path %@", [self className], _cmd, path);
		NSBeep(); return;
	}
	
	// insert the recording
	id theTarget = [NSApp targetForAction:@selector(sproutedSnapshot:insertRecording:title:) to:nil from:self];
	if ( theTarget != nil )
	{
		[theTarget sproutedSnapshot:self insertRecording:path title:nil];
	}
	else
	{
		NSBeep();
		NSLog(@"%@ %s - invalid target", [self className], _cmd);
	}
}

#pragma mark -

- (void) _snapshotCountdown:(NSTimer*)aTimer
{
	if ( countdown <= 0 )
	{
		[coundownField setHidden:YES];
		[shutterSound play];
		
		if ( capturing ) 
		{
			[camera stop];
			capturing = NO;
		}
		
		NSImage *theImage = [cameraView image];
		NSMutableArray *myImages = [[[self images] mutableCopyWithZone:[self zone]] autorelease];
		
		[myImages replaceObjectAtIndex:currentSlot withObject:theImage];
		[self setImages:myImages];
		
		if ( ++currentSlot >= 4 ) currentSlot = 0;
		slotsTaken++;
		
		// invalidate the timer
		[snapshotTimer invalidate];
		[snapshotTimer release], snapshotTimer = nil;
		
		// start up the reset timer
		resetTimer = [[[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:1.6] 
				interval:0 
				target:self 
				selector:@selector(reset:) 
				userInfo:nil 
				repeats:NO] autorelease];
				
		[[NSRunLoop currentRunLoop] addTimer:resetTimer forMode:NSDefaultRunLoopMode];
	}
	else
	{
		if ( [countdownSound isPlaying] ) [countdownSound stop];
		[countdownSound play];
		
		[coundownField setStringValue:[NSString stringWithFormat:@"%i",countdown]];
		countdown--;
	}

}

@end
