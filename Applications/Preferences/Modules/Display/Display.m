/*
  Display.m

  Controller class for Display preferences bundle

  Author:	Sergii Stoian <stoyan255@ukr.net>
  Date:		28 Nov 2015

  This program is free software; you can redistribute it and/or
  modify it under the terms of the GNU General Public License as
  published by the Free Software Foundation; either version 2 of
  the License, or (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public
  License along with this program; if not, write to:

  Free Software Foundation, Inc.
  59 Temple Place - Suite 330
  Boston, MA  02111-1307, USA
*/
#import <AppKit/NSApplication.h>
#import <AppKit/NSNibLoading.h>
#import <AppKit/NSView.h>
#import <AppKit/NSBox.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSPopUpButton.h>
#import <AppKit/NSBrowser.h>
#import <AppKit/NSBrowserCell.h>
#import <AppKit/NSMatrix.h>
#import <AppKit/NSSlider.h>

#import <NXSystem/NXScreen.h>
#import <NXSystem/NXDisplay.h>

#import "Display.h"

@implementation DisplayPrefs

static NSBundle                 *bundle = nil;
static NSUserDefaults           *defaults = nil;
static NSMutableDictionary      *domain = nil;
static NXDisplay		*selectedDisplay = nil;

- (id)init
{
  self = [super init];
  
  defaults = [NSUserDefaults standardUserDefaults];
  domain = [[defaults persistentDomainForName:NSGlobalDomain] mutableCopy];

  bundle = [NSBundle bundleForClass:[self class]];
  NSString *imagePath = [bundle pathForResource:@"Monitor" ofType:@"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile:imagePath];
      
  return self;
}

- (void)dealloc
{
  [image release];
  [super dealloc];
}

- (void)awakeFromNib
{
  [view retain];
  [window release];

  [monitorsList loadColumnZero];
  {
    NSArray *cells = [[monitorsList matrixInColumn:0] cells];
    int i;
    for (i = 0; i < [cells count]; i++)
      {
        if ([[cells objectAtIndex:i] isEnabled] == YES)
          {
            [monitorsList selectRow:i inColumn:0];
            break;
          }
      }
  }
  [self monitorsListClicked:monitorsList];
  
  [rotationBtn setEnabled:NO];
  [reflectionBtn setEnabled:NO];
}

- (NSView *)view
{
  if (view == nil)
    {
      if (![NSBundle loadNibNamed:@"Display" owner:self])
        {
          NSLog (@"Display.preferences: Could not load NIB, aborting.");
          return nil;
        }
    }

  return view;
}

- (NSString *)buttonCaption
{
  return @"Display Preferences";
}

- (NSImage *)buttonImage
{
  return image;
}

//
// Action methods
//
- (IBAction)monitorsListClicked:(id)sender
{
  NSArray      *m;
  NSSize       size;
  NSString     *resolution;
  NSDictionary *r;

  selectedDisplay = [[sender selectedCell] representedObject];
  m = [selectedDisplay allModes];
  // NSLog(@"Display.preferences: selected monitor with title: %@", mName);

  // Resolution
  [resolutionBtn removeAllItems];
  for (NSDictionary *res in m)
    {
      size = NSSizeFromString([res objectForKey:@"Dimensions"]);
      resolution = [NSString stringWithFormat:@"%.0fx%.0f",
                             size.width, size.height];
      [resolutionBtn addItemWithTitle:resolution];
    }
  r = [selectedDisplay mode];
  [resolutionBtn selectItemAtIndex:[m indexOfObject:r]];
  // Rate button filled here. Items tagged with resolution description
  // object in [NSDisplay allModes] array
  [self resolutionClicked:resolutionBtn];

  // Gamma
  CGFloat gamma = [selectedDisplay gammaValue].red;
  [gammaSlider setFloatValue:1.0/gamma];
  [gammaField
    setStringValue:[NSString stringWithFormat:@"%.2f", 1.0/gamma]];

  // Brightness
  CGFloat brightness = [selectedDisplay gammaBrightness];
  [brightnessSlider setFloatValue:brightness * 100];
  [brightnessField
    setStringValue:[NSString stringWithFormat:@"%.0f", brightness * 100]];
}

- (IBAction)resolutionClicked:(id)sender
{
  NSString  *mName = [[monitorsList selectedCell] title];
  NSString  *resString = [sender titleOfSelectedItem]; // "1920 x 1200"
  NXDisplay *d = [[NXScreen sharedScreen] displayWithName:mName];
  NSArray   *m = [d allModes];
  NSString  *rateString;
  NSDictionary *res;

  [rateBtn removeAllItems];
  for (NSInteger i = 0; i < [m count]; i++)
    {
      res = [m objectAtIndex:i];
      if ([[res objectForKey:@"Name"] rangeOfString:resString].location !=
          NSNotFound)
        {
          rateString = [NSString stringWithFormat:@"%.1f Hz",
                               [[res objectForKey:@"Rate"] floatValue]];
          [rateBtn addItemWithTitle:rateString];
          [[rateBtn itemWithTitle:rateString] setRepresentedObject:res];
        }
    }

  [rateBtn setEnabled:([[rateBtn itemArray] count] == 1) ? NO : YES];
  
  // NSLog(@"Selected resolution: %@",
  //       [[rateBtn selectedCell] representedObject]);
}

- (IBAction)rateClicked:(id)sender
{
  // NSString  *mName = [[monitorsList selectedCell] title];
  // NXDisplay *d = [[NXScreen sharedScreen] displayWithName:mName];

  // NSLog(@"rateClicked: Selected resolution: %@",
  //       [[rateBtn selectedCell] representedObject]);
}

- (IBAction)sliderMoved:(id)sender
{
  CGFloat value = [sender floatValue];
  
  if (sender == gammaSlider)
    {
      // NSLog(@"Gamma slider moved");
      [gammaField setStringValue:[NSString stringWithFormat:@"%.2f", value]];
      [selectedDisplay
        setGammaCorrectionValue:value
                     brightness:[brightnessSlider floatValue]/100];
    }
  else if (sender == brightnessSlider)
    {
      // NSLog(@"Brightness slider moved");
      [brightnessField setIntValue:[sender intValue]];
      [selectedDisplay setGammaCorrectionValue:[gammaSlider floatValue]
                                    brightness:value/100];
    }
  else
    NSLog(@"Unknown slider moved");  
}

//
// Browser Delegate methods
//
- (NSString *)browser:(NSBrowser *)sender titleOfColumn:(NSInteger)column
{
  if (column > 0)
    return @"";

  return @"Monitors";
}

- (void)     browser:(NSBrowser *)sender
 createRowsForColumn:(NSInteger)column
            inMatrix:(NSMatrix *)matrix
{
  NSArray *displays;
  NSBrowserCell *bc;

  if (column > 0)
    return;

  NSLog(@"browser:createRowsForColumn:inMatrix:");
 
  displays = [[NXScreen sharedScreen] connectedDisplays];
    
  for (NXDisplay *d in displays)
    {
      [matrix addRow];
      bc = [matrix cellAtRow:[matrix numberOfRows]-1 column:0];
      [bc setTitle:[d outputName]];
      [bc setLeaf:YES];
      [bc setRefusesFirstResponder:YES];
      [bc setRepresentedObject:d];
      // if (![d isActive])
      //   {
      //     [bc setEnabled:NO];
      //   }
    }
}

// - (void) browser:(NSBrowser *)sender
//  willDisplayCell:(id)cell
//            atRow:(NSInteger)row
//           column:(NSInteger)column
// {
//   NSLog(@"browser:willDisplayCell: %@ (selected=%@)",
//         [cell title], [[sender selectedCell] title]);
// }

// - (void) browser:(NSBrowser *)sender
//        selectRow:(NSInteger)row
//         inColumn:(NSInteger)column
// {
//   NSLog(@"browser:selectRow:inColumn: %@",
//         [[sender loadedCellAtRow:row column:column] title]);
//   [self monitorsListClicked:sender];
// }

//
// TextField Delegate methods
//
// - (BOOL)textShouldEndEditing:(NSText *)textObject
// {
//   NSString *text = [textObject text];

  
// }

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
  id      tf = [aNotification object];
  CGFloat value = [tf floatValue];

  if (tf == gammaField)
    {
      [gammaSlider setFloatValue:value];
      [selectedDisplay setGammaCorrectionValue:value];
    }
  else if (tf == brightnessField)
    {
      [brightnessSlider setFloatValue:value];
      [selectedDisplay setGammaBrightness:value/100];
    }
}
  
@end
