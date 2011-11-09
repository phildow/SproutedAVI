//
//  SproutedAVIController.m
//  Sprouted AVI
//
//  Created by Philip Dow on 4/23/08.
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


#import <SproutedAVI/SproutedAVIController.h>
#import <SproutedAVI/SproutedAVIPreferences.h>
#import <SproutedAVI/SproutedAVIImageAdditions.h>

// shared
#import <SproutedAVI/SproutedAudioRecorder.h>

// tiger
#import <SproutedAVI/SproutedSnapshot.h>
#import <SproutedAVI/SproutedTigerAudioRecorder.h>
#import <SproutedAVI/SproutedVideoRecorder.h>

// leopard
#import <SproutedAVI/SproutedLeopardVideoRecorder.h>
#import <SproutedAVI/SproutedLeopardAudioRecorder.h>


// set the hide/deactive option on the window
//	if ( GetCurrentKeyModifiers() & optionKey )
//		[[self window] setHidesOnDeactivate:NO];

#warning leaking a little memory when recording audio
#warning leaking a lot of memory when recording video - sound and video Media?

#warning make it possible to record video without sound
#warning window frame saving doesn't quite work because the frame size changes

NSString *kExpirationDate = @"2009-12-31 01:01:01 -0600";
							//YYYY-MM-DD HH:MM:SS ±HHMM


static NSString *kSproutedAVIToolbarIdentifier = @"SproutedAVIToolbarIdentifier";

static NSString *kRecordAudioToolbarItemIdentifier = @"RecordAudioToolbarItemIdentifier";
static NSString *kRecordVideoToolbarItemIdentifier = @"RecordVideoToolbarItemIdentifier";
static NSString *kSnapshotToolbarItemIdentifier = @"SnapshotToolbarItemIdentifier";
static NSString *kPreferecnesToolbarItemIdentifier = @"PreferecnesToolbarItemIdentifier";


@implementation SproutedAVIController

+ (void)initialize
{	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSBundle *myBundle = [NSBundle bundleWithIdentifier:@"com.sprouted.avi"];
   
	 NSString *defaultArtist = NSFullUserName();
	if ( defaultArtist == nil ) defaultArtist = NSUserName();
	if ( defaultArtist == nil ) defaultArtist = NSLocalizedStringFromTableInBundle(@"default artist",
										@"Localizable",
										myBundle,
										@"");
	
	NSString *defaultAlbum = NSLocalizedStringFromTableInBundle(@"default album",
										@"Localizable",
										myBundle,
										@"");
	
	NSString *defaultPlaylist = NSLocalizedStringFromTableInBundle(@"default playlist",
										@"Localizable",
										myBundle,
										@"");
    
	NSDictionary *appDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithBool:YES], @"WarnOfUnsavedRecordings",
			[NSNumber numberWithInt:0], @"AudioRecordingFormat",
			[NSNumber numberWithInt:0], @"DefaultVideoCodec",
			[NSNumber numberWithInt:0], @"AddRecordingToITunes",
			defaultArtist, @"DefaultArtist",
			defaultAlbum, @"DefaultAlbum",
			defaultPlaylist, @"DefaultPlaylist", nil];
 
    [defaults registerDefaults:appDefaults];
}

+ (id) sharedController
{
	static SproutedAVIController *sharedController = nil;

    if (!sharedController) 
	{
        sharedController = [[SproutedAVIController allocWithZone:NULL] init];
    }

    return sharedController;
}

#pragma mark -

- (id) init
{
	if ( self = [super initWithWindowNibName:@"AVIController"] )
	{
		/*
		if ( [self frameworkHasntExpired] == NO )
		{
			NSBeep();
			NSLog(@"%@ %s - the sprouted AVI framework has expired. Please download the latest version if one is available.", [self className], _cmd);
			
			[self release];
			return nil;
		}
		*/
	}
	return self;
}

- (void) dealloc
{
	[placeholder release], placeholder = nil;
	[activeRecorder release], activeRecorder = nil;
	[audioRecordingAttributes release], audioRecordingAttributes = nil;
	
	[super dealloc];
}

- (void) windowDidLoad
{
	[self setupToolbar];
	
	if ( [[self window] respondsToSelector:@selector(setContentBorderThickness:forEdge:)] )
	{
		[placeholderGradient setHidden:YES];
		[[self window] setContentBorderThickness:50.0 forEdge:NSMinYEdge];
	}
	else
	{
		int borders[4] = {1,0,0,0};
		[placeholderGradient setBorders:borders];
		[placeholderGradient setBordered:YES];
		[placeholderGradient setHidden:NO];
		
		[[self window] setBackgroundColor:[NSColor colorWithCalibratedWhite:0.9 alpha:0.96]];
	}
	
	activeView = [placeholder retain];
}

- (BOOL)windowShouldClose:(id)window
{
	if ( window == [self window] )
		return [self _shouldCloseActiveRecorder:[self className]];
	else
		return YES;
}

- (void) windowWillClose:(NSNotification*)aNotification
{
	if ( [aNotification object] == [self window] )
	{
		NSRect contentFrame = [activeView frame];
		[placeholder setFrame:contentFrame];
		
		[[self activeRecorder] recorderWillClose:nil];
		
		[[[[self activeRecorder] view] superview] replaceSubview:[[self activeRecorder] view] with:placeholder];
		
		[[self activeRecorder] recorderDidClose:nil];
		[self setSelectedToolbarItemIdentifier:nil];
		[self setActiveRecorder:nil];
		activeView = placeholder;
	}
}

#pragma mark -

- (id) delegate
{
	return delegate;
}

- (void) setDelegate:(id)anObject
{
	delegate = anObject;
}

- (SproutedRecorder*) activeRecorder
{
	return activeRecorder;
}

- (void) setActiveRecorder:(SproutedRecorder*)aRecorder
{
	if ( activeRecorder != aRecorder )
	{
		[activeRecorder release];
		activeRecorder = [aRecorder retain];
	}
}

- (NSString*) selectedToolbarItemIdentifier
{
	return selectedToolbarItemIdentifier;
}

- (void) setSelectedToolbarItemIdentifier:(NSString*)anIdentifier
{
	if ( selectedToolbarItemIdentifier != anIdentifier )
	{
		[selectedToolbarItemIdentifier release];
		selectedToolbarItemIdentifier = [anIdentifier copyWithZone:[self zone]];
	}
}

- (void) setAudioRecordingAttributes:(NSDictionary*)aDictionary
{
	if ( audioRecordingAttributes != aDictionary )
	{
		[audioRecordingAttributes release];
		audioRecordingAttributes = [aDictionary copyWithZone:[self zone]];
		
		if ( [[self activeRecorder] isKindOfClass:[SproutedAudioRecorder class]] )
			[(SproutedAudioRecorder*)[self activeRecorder] setRecordingAttributes:aDictionary];
	}
}

#pragma mark -

- (IBAction)showWindow:(id)sender
{
	if ( [self delegateIsValid] )
		[super showWindow:sender];
	else
		NSLog(@"%@ %s - you are not authorized to use this framework", [self className], _cmd);
}

- (void) showError:(NSString*)error
{
	NSRect placeholderFrame = NSMakeRect(0,0,320,429);
	[placeholder setFrame:placeholderFrame];
	
	[errorImageView setImage:[NSImage coreTypesImageNamed:@"AlertCautionIcon.icns"]];
	[errorField setStringValue:(error != nil ? error : [NSString string])];
	
	[sproutedImageView setHidden:YES];
	[errorImageView setHidden:NO];
	[errorField setHidden:NO];
	
	NSRect contentFrame = placeholderFrame;
	
	if ( activeView != placeholder ) [activeView setHidden:YES];
	[self _resizeWindowForContentSize:contentFrame.size];
	
	[[activeView superview] replaceSubview:activeView with:placeholder];
	[placeholder setHidden:NO];
	activeView = placeholder;
}

- (IBAction) showAVIPreferences:(id)sender
{
	if ( ![[self activeRecorder] isKindOfClass:[SproutedAVIPreferences class]] )
	{
		if ( [self _shouldCloseActiveRecorder:NSStringFromClass([SproutedAVIPreferences class])] )
		{
			BOOL displayed = [self _displayAVIPreferences];
			if ( displayed )
			{
				if ( ![[[[self window] toolbar] selectedItemIdentifier] isEqualToString:kPreferecnesToolbarItemIdentifier] )
					[[[self window] toolbar] setSelectedItemIdentifier:kPreferecnesToolbarItemIdentifier];
				
				[[self window] setTitle:NSLocalizedStringFromTableInBundle(@"preferences title",
						@"Localizable",
						[NSBundle bundleWithIdentifier:@"com.sprouted.avi"],
						@"")];
			}
		}
	}
}

#pragma mark -

- (IBAction) recordAudio:(id)sender
{
	if ( ![[self activeRecorder] isKindOfClass:[SproutedTigerAudioRecorder class]] 
			|| [[self activeRecorder] isKindOfClass:[SproutedLeopardAudioRecorder class]] )
	{
		NSString *classString = NSStringFromClass( [self respondsToSelector:@selector(cursorUpdate:)] ? 
				[SproutedLeopardAudioRecorder class] : 
				[SproutedTigerAudioRecorder class] );
		
		if ( [self _shouldCloseActiveRecorder:classString] )
		{
			BOOL displayed = [self _displayAudioRecorder];
			
			if ( displayed )
			{
				if ( audioRecordingAttributes != nil ) 
					[(SproutedAudioRecorder*)[self activeRecorder] setRecordingAttributes:audioRecordingAttributes];
				
				if ( ![[[[self window] toolbar] selectedItemIdentifier] isEqualToString:kRecordAudioToolbarItemIdentifier] )
					[[[self window] toolbar] setSelectedItemIdentifier:kRecordAudioToolbarItemIdentifier];
				
				[[self window] setTitle:NSLocalizedStringFromTableInBundle(@"record audio title",
						@"Localizable",
						[NSBundle bundleWithIdentifier:@"com.sprouted.avi"],
						@"")];
			}
		}
	}
}

- (IBAction) recordVideo:(id)sender
{
	if ( !( [[self activeRecorder] isKindOfClass:[SproutedVideoRecorder class]] 
			|| [[self activeRecorder] isKindOfClass:[SproutedLeopardVideoRecorder class]] ) )
	{
		NSString *classString = NSStringFromClass( [self respondsToSelector:@selector(cursorUpdate:)] ? 
				[SproutedLeopardVideoRecorder class] : 
				[SproutedVideoRecorder class] );
				
		if ( [self _shouldCloseActiveRecorder:classString] )
		{
			BOOL displayed = [self _displayVideoRecorder];
			if ( displayed )
			{
				if ( ![[[[self window] toolbar] selectedItemIdentifier] isEqualToString:kRecordVideoToolbarItemIdentifier] )
					[[[self window] toolbar] setSelectedItemIdentifier:kRecordVideoToolbarItemIdentifier];
				
				[[self window] setTitle:NSLocalizedStringFromTableInBundle(@"record video title",
						@"Localizable",
						[NSBundle bundleWithIdentifier:@"com.sprouted.avi"],
						@"")];
			}
		}
	}
}

- (IBAction) takeSnapshot:(id)sender
{
	if ( ![[self activeRecorder] isKindOfClass:[SproutedSnapshot class]] )
	{
		if ( [self _shouldCloseActiveRecorder:NSStringFromClass([SproutedSnapshot class])] )
		{
			BOOL displayed = [self _displayPictureTaker];
			if ( displayed )
			{
				if ( ![[[[self window] toolbar] selectedItemIdentifier] isEqualToString:kSnapshotToolbarItemIdentifier] )
					[[[self window] toolbar] setSelectedItemIdentifier:kSnapshotToolbarItemIdentifier];
				
				[[self window] setTitle:NSLocalizedStringFromTableInBundle(@"take snapshot title",
						@"Localizable",
						[NSBundle bundleWithIdentifier:@"com.sprouted.avi"],
						@"")];
			}
		}
	}
}

#pragma mark -

- (BOOL) _displayAVIPreferences
{
	SproutedAVIPreferences *preferences = [[[SproutedAVIPreferences alloc] initWithController:self] autorelease];	
	NSRect contentFrame = [[preferences view] frame];
	
	[[self activeRecorder] recorderWillClose:nil];
	[preferences recorderWillLoad:nil];
	
	[activeView setHidden:YES];
	[self _resizeWindowForContentSize:contentFrame.size];
	
	[[activeView superview] replaceSubview:activeView with:[preferences view]];
	
	[[self activeRecorder] recorderDidClose:nil];
	[preferences recorderDidLoad:nil];
	
	[self setSelectedToolbarItemIdentifier:kPreferecnesToolbarItemIdentifier];
	[self setActiveRecorder:preferences];
	activeView = [preferences view];
	
	return YES;
}

- (BOOL) _displayAudioRecorder
{
	BOOL success;
	SproutedRecorder *audioRecorder = [[[SproutedTigerAudioRecorder alloc] initWithController:self] autorelease];
	
	if ( audioRecorder == nil )
	{
		[[self activeRecorder] recorderWillClose:nil];
		[[self activeRecorder] recorderDidClose:nil];
		
		[self showError:[self noAudioError]];
		[self setSelectedToolbarItemIdentifier:nil];
		[self setActiveRecorder:nil];
	}
	else
	{
		NSRect contentFrame = [[audioRecorder view] frame];
		
		[[self activeRecorder] recorderWillClose:nil];
		success = [audioRecorder recorderWillLoad:nil];
		
		if ( !success )
		{
			[[self activeRecorder] recorderDidClose:nil];
			[self showError:[audioRecorder error]];
			
			[self setSelectedToolbarItemIdentifier:nil];
			[self setActiveRecorder:nil];
		}
		else
		{
			[activeView setHidden:YES];
			[self _resizeWindowForContentSize:contentFrame.size];
			
			[[activeView superview] replaceSubview:activeView with:[audioRecorder view]];
			
			[[self activeRecorder] recorderDidClose:nil];
			success = [audioRecorder recorderDidLoad:nil];
			
			if ( !success )
			{
				activeView = [audioRecorder view];
				[self showError:[audioRecorder error]];
				
				[self setSelectedToolbarItemIdentifier:nil];
				[self setActiveRecorder:nil];
			}
			else
			{
				[self setSelectedToolbarItemIdentifier:kRecordAudioToolbarItemIdentifier];
				[self setActiveRecorder:audioRecorder];
				activeView = [audioRecorder view];
			}
		}
	}
	
	return success;
}

- (BOOL) _displayVideoRecorder
{
	BOOL success;
	SproutedRecorder *videoRecorder = ( [self respondsToSelector:@selector(cursorUpdate:)] ? 
			[[[SproutedLeopardVideoRecorder alloc] initWithController:self] autorelease] :
			[[[SproutedVideoRecorder alloc] initWithController:self] autorelease] );
			
	if ( videoRecorder == nil )
	{
		[[self activeRecorder] recorderWillClose:nil];
		[[self activeRecorder] recorderDidClose:nil];
		
		[self showError:[self noVideoError]];
		
		[self setSelectedToolbarItemIdentifier:nil];
		[self setActiveRecorder:nil];
	}
	else
	{
		NSRect contentFrame = [[videoRecorder view] frame];
		
		[[self activeRecorder] recorderWillClose:nil];
		success = [videoRecorder recorderWillLoad:nil];
		
		if ( !success )
		{
			[[self activeRecorder] recorderDidClose:nil];
			[self showError:[videoRecorder error]];
			
			[self setSelectedToolbarItemIdentifier:nil];
			[self setActiveRecorder:nil];
		}
		else
		{
			[activeView setHidden:YES];
			[self _resizeWindowForContentSize:contentFrame.size];
			
			[[activeView superview] replaceSubview:activeView with:[videoRecorder view]];
			
			[[self activeRecorder] recorderDidClose:nil];
			success = [videoRecorder recorderDidLoad:nil];
			
			if ( !success )
			{
				activeView = [videoRecorder view];
				[self showError:[videoRecorder error]];
				
				[self setSelectedToolbarItemIdentifier:nil];
				[self setActiveRecorder:nil];
			}
			else
			{
				[self setSelectedToolbarItemIdentifier:kRecordVideoToolbarItemIdentifier];
				[self setActiveRecorder:videoRecorder];
				activeView = [videoRecorder view];
			}
		}
	}
	
	return success;
}

- (BOOL) _displayPictureTaker
{
	BOOL success;
	SproutedSnapshot *snapshot = [[[SproutedSnapshot alloc] initWithController:self] autorelease];
	if ( snapshot == nil )
	{
		[[self activeRecorder] recorderWillClose:nil];
		[[self activeRecorder] recorderDidClose:nil];
		
		[self showError:[self noSnapshotError]];
		
		[self setSelectedToolbarItemIdentifier:nil];
		[self setActiveRecorder:nil];
	}
	else
	{
		NSRect contentFrame = [[snapshot view] frame];
		
		[[self activeRecorder] recorderWillClose:nil];
		success = [snapshot recorderWillLoad:nil];
		
		if ( !success )
		{
			[[self activeRecorder] recorderDidClose:nil];
			[self showError:[snapshot error]];
			
			[self setSelectedToolbarItemIdentifier:nil];
			[self setActiveRecorder:nil];
		}
		else
		{
			[activeView setHidden:YES];
			[self _resizeWindowForContentSize:contentFrame.size];
			
			[[activeView superview] replaceSubview:activeView with:[snapshot view]];
			
			[[self activeRecorder] recorderDidClose:nil];
			success = [snapshot recorderDidLoad:nil];
			
			if ( !success )
			{
				activeView = [snapshot view];
				[self showError:[snapshot error]];
				
				[self setSelectedToolbarItemIdentifier:nil];
				[self setActiveRecorder:nil];
			}
			else
			{
				[self setSelectedToolbarItemIdentifier:kSnapshotToolbarItemIdentifier]; 
				[self setActiveRecorder:snapshot];
				activeView = [snapshot view];
			}
		}
	}
	
	return success;
}

#pragma mark -

- (BOOL) _shouldCloseActiveRecorder:(NSString*)wantedRecorder
{
	BOOL shouldClose = YES;
	NSError *anError = nil;
	
	if ( [self activeRecorder] == nil )
	{
		shouldClose = YES;
	}
	else if ( ![[self activeRecorder] recorderShouldClose:nil error:&anError] )
	{
		// always return no
		// but proceed if the recovery attempt succeeded
		// will only know that in the sheet return delegate
		
		shouldClose = NO;
		
		if ( anError == nil )
			NSLog(@"%@ %s - expected an error", [self className], _cmd);
		else
		{
			[wantedRecorder retain];
			
			[self presentError:anError 
					modalForWindow:[self window] 
					delegate:self 
					didPresentSelector:@selector(didPresentShouldCloseErrorWithRecovery:contextInfo:) 
					contextInfo:wantedRecorder];
		}
	}
	else
	{
		shouldClose = YES; 
	}
	
	return shouldClose;
}

- (void) didPresentShouldCloseErrorWithRecovery:(BOOL)didRecover contextInfo:(void *)contextInfo
{
	if ( didRecover )
	{
		NSString *wantedRecorder = (NSString*)contextInfo;
		// wantedRecorder will be my classname when the user requested that the window close
		// otherwise it will indicate which recorder is to be loaded
		
		if ( [wantedRecorder isEqualToString:[self className]] )
			[self close];
		else if ( [wantedRecorder isEqualToString:NSStringFromClass([SproutedSnapshot class])] )
			[self _displayPictureTaker];
		else if ( [wantedRecorder isEqualToString:NSStringFromClass([SproutedTigerAudioRecorder class])] 
				|| [wantedRecorder isEqualToString:NSStringFromClass([SproutedLeopardAudioRecorder class])] )
			[self _displayAudioRecorder];
		else if ( [wantedRecorder isEqualToString:NSStringFromClass([SproutedVideoRecorder class])]
				|| [wantedRecorder isEqualToString:NSStringFromClass([SproutedLeopardVideoRecorder class])] )
			[self _displayVideoRecorder];
		else if ( [wantedRecorder isEqualToString:NSStringFromClass([SproutedAVIPreferences class])] )
			[self _displayAVIPreferences];
		else
			NSLog(@"%@ %s - don't know how to handle the action", [self className], _cmd);
	}
	else
	{
		// reselect the old item in the toolbar
		// is it possible for the old item to be nil? if so, can you deselect?
		[[[self window] toolbar] performSelector:@selector(setSelectedItemIdentifier:) 
				withObject:[self selectedToolbarItemIdentifier] 
				afterDelay:0.1];
	}
	
	[(NSString*)contextInfo release];
}

#pragma mark -

- (NSString*) noSnapshotError
{
	NSString *errorMsg = NSLocalizedStringFromTableInBundle(
			@"no snapshot capture msg", 
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"");
	NSString *errorInfo = NSLocalizedStringFromTableInBundle(
			@"no snapshot capture info", 
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"");
	
	NSString *errorString = [NSString stringWithFormat:@"%@\n\n%@", errorMsg, errorInfo];
	return errorString;
}

- (NSString*) noAudioError
{
	NSString *errorMsg = NSLocalizedStringFromTableInBundle(
			@"no audio capture msg", 
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"");
	NSString *errorInfo = NSLocalizedStringFromTableInBundle(
			@"no audio capture info", 
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"");
	
	NSString *errorString = [NSString stringWithFormat:@"%@\n\n%@", errorMsg, errorInfo];
	return errorString;
}

- (NSString*) noVideoError
{
	NSString *errorMsg = NSLocalizedStringFromTableInBundle(
			@"no video capture msg", 
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"");
	NSString *errorInfo = NSLocalizedStringFromTableInBundle(
			@"no video capture info", 
			@"Localizable", 
			[NSBundle bundleWithIdentifier:@"com.sprouted.avi"], 
			@"");
	
	NSString *errorString = [NSString stringWithFormat:@"%@\n\n%@", errorMsg, errorInfo];
	return errorString;
}

#pragma mark -

- (void)cancelOperation:(id)sender
{
	[[self window] performClose:sender];
}

- (void) _resizeWindowForContentSize:(NSSize) size 
{
	int newViewFrameHeight = size.height;
	NSRect contentRect = [[self window] contentRectForFrameRect:[[self window] frame]];
	
	contentRect.origin.y = contentRect.origin.y + contentRect.size.height - newViewFrameHeight;
	contentRect.size.height = newViewFrameHeight;
		
	NSRect newFrame = [[self window] frameRectForContentRect:contentRect];
			
	[[self window] setFrame:newFrame 
			display:YES 
			animate:YES];
}

- (BOOL) delegateIsValid
{
	if ( ![self isMemberOfClass:[SproutedAVIController class]] )
		return NO;
	else if ( delegate == nil || ![delegate respondsToSelector:@selector(validateYourself:)] )
		return NO;
	else
	{
		id validationNumber = [delegate validateYourself:self];
		
		if ( ![validationNumber isKindOfClass:[NSNumber class]] )
			return NO;
		else
		{
			NSBundle *framework = [NSBundle bundleWithIdentifier:@"com.sprouted.avi"];
			NSString *executablePath = [framework executablePath];
			
			NSNumber *executableSize = [[[NSFileManager defaultManager] 
					fileAttributesAtPath:executablePath 
					traverseLink:NO]
					objectForKey:NSFileSize];
					
			return ( [(NSNumber*)validationNumber isEqualToNumber:executableSize] );
		}
	}
}

- (BOOL) frameworkHasntExpired
{
	if ( ![self isMemberOfClass:[SproutedAVIController class]] )
		return NO;
	else
	{
		NSDate *expirationDate = [NSDate dateWithString:kExpirationDate];
		NSDate *todaysDate = [NSDate date];
		
		if ( [expirationDate compare:todaysDate] == NSOrderedAscending )
			return NO;
		else	
			return YES;
	}
}
		

#pragma mark -
#pragma mark Toolbar

- (void) setupToolbar
{
	//building and displaying the toolbar
    NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier: kSproutedAVIToolbarIdentifier] autorelease];
	
    [toolbar setDisplayMode: NSToolbarDisplayModeIconOnly];
	[toolbar setSizeMode:NSToolbarSizeModeRegular];
	[toolbar setAllowsUserCustomization:NO];
	[toolbar setAutosavesConfiguration:NO];
    [toolbar setDelegate: self];
	
    [[self window] setToolbar: toolbar];
}

- (NSToolbarItem *) toolbar: (NSToolbar *)toolbar 
		itemForItemIdentifier:(NSString *)itemIdent 
		willBeInsertedIntoToolbar:(BOOL)willBeInserted 
{	
	NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier: itemIdent];
	NSBundle *myBundle = [NSBundle bundleWithIdentifier:@"com.sprouted.avi"];
	
	if ( [itemIdent isEqual:kRecordAudioToolbarItemIdentifier]) 
	{
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(recordAudio:)];
		
		[toolbarItem setLabel:NSLocalizedStringFromTableInBundle(@"Audio", @"Localizable", myBundle, nil)];
		[toolbarItem setImage:[[[NSImage alloc] initWithContentsOfFile:[myBundle pathForImageResource:@"ToolbarItemRecordAudio.png"]] autorelease]];
    }
	else if ( [itemIdent isEqual:kRecordVideoToolbarItemIdentifier]) 
	{
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(recordVideo:)];
		
		[toolbarItem setLabel:NSLocalizedStringFromTableInBundle(@"Video", @"Localizable", myBundle, nil)];
		[toolbarItem setImage:[[[NSImage alloc] initWithContentsOfFile:[myBundle pathForImageResource:@"ToolbarItemRecordVideo.png"]] autorelease]];
    }
	else if ( [itemIdent isEqual:kSnapshotToolbarItemIdentifier]) 
	{
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(takeSnapshot:)];
		
		[toolbarItem setLabel:NSLocalizedStringFromTableInBundle(@"Snapshot", @"Localizable", myBundle, nil)];
		[toolbarItem setImage:[[[NSImage alloc] initWithContentsOfFile:[myBundle pathForImageResource:@"ToolbarItemSnapshot.png"]] autorelease]];
    }
	else if ( [itemIdent isEqual:kPreferecnesToolbarItemIdentifier]) 
	{
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(showAVIPreferences:)];
		
		[toolbarItem setLabel:NSLocalizedStringFromTableInBundle(@"Options", @"Localizable", myBundle, nil)];
		[toolbarItem setImage:[[[NSImage alloc] initWithContentsOfFile:[myBundle pathForImageResource:@"get-info-32.tiff"]] autorelease]];
    }
	else 
	{
		[toolbarItem release];
		toolbarItem = nil;
	}
	
	return [toolbarItem autorelease];
}

- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar 
{
	return [NSArray arrayWithObjects:
			kRecordAudioToolbarItemIdentifier, 
			kRecordVideoToolbarItemIdentifier, 
			kSnapshotToolbarItemIdentifier,
			NSToolbarFlexibleSpaceItemIdentifier, 
			kPreferecnesToolbarItemIdentifier, nil];
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar 
{
	return [NSArray arrayWithObjects:
			kRecordAudioToolbarItemIdentifier, 
			kRecordVideoToolbarItemIdentifier, 
			kSnapshotToolbarItemIdentifier,
			NSToolbarFlexibleSpaceItemIdentifier, 
			kPreferecnesToolbarItemIdentifier, nil];
}

- (BOOL) validateToolbarItem: (NSToolbarItem *) toolbarItem
{
	return YES;
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar 
{
	static int kToolbarItemGetInfoTag = 201;
	
	NSMutableArray *theArray = [[NSMutableArray alloc] init];
	
	NSToolbarItem *currentItem;
	NSEnumerator *enumerator = [[toolbar items] objectEnumerator];
	
	while ( currentItem = [enumerator nextObject] ) {
		if ( [currentItem tag] != kToolbarItemGetInfoTag )
			[theArray addObject:[currentItem itemIdentifier]];
	}
	
	[theArray autorelease];
	return theArray;
}

@end
