
//  Created by Philip Dow
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

//
//	Please note that Cocoa Sequence Grabber Code from Tim Omernick
//	is also used in this project and may require accreditation.
//		CSGCamera.h
//		CSGCamera.m
//		CSGImage.h
//		CSGImage.m
//

//	SPROUTED DEPENDENCIES
//	i.	SproutedUtilities
//	ii. SproutedInterface

//	ABOUT
//	SproutedAVI is the almost herculean effort to combine audio, video and image
//	recording into a protable framework for use in any application. It is the 
//	same code Journler uses. The code was originally written for Mac OS 10.4 Tiger
//  and employs the old Sequence Grabbing classes provided by Apple. 

//  Modern versions 
//  of the OS offer the excellent QTKit / QTCapture API which is considerably simpler 
//  to use, and code for 10.5 and higher was written to take advantage of them. Newer 
//  versions of the OS provide additional APIs through the QTCapture classes which
//  aren't used here but are being employed in Per Se. I may eventually release the
//  AVI code I am currently using in that application.

//  I haven't yet tried to compile the code on Mac OS 10.7, but it should compile
//  fine on 10.5 and possibly 10.6, and to my knowledge the binaries continue to work fine
//  on recent versions of the Mac OS.