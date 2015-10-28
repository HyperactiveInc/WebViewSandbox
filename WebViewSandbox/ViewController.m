//
//  ViewController.m
//  WebViewSandbox
//
//  Created by Anton Kolchunov on 20.02.15.
//  Copyright (c) 2015 Hyperactive Inc. All rights reserved.
//

#import "ViewController.h"
#import "ZipArchive.h"

static NSString * const ARCHIEVE_NAME = @"sample-contentitem";

@interface ViewController () {
  
  NSURL *_contentURL;
  
}

@property (nonatomic, weak) IBOutlet UIView *hostView;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *activityIndicator;

@property (nonatomic, strong) UIWebView *presentWebView;

@end

@implementation ViewController

- (UIWebView *)presentWebView;
{
  if ( !_presentWebView ) {
	UIWebView *webView = [[UIWebView alloc] init];
	webView.opaque = NO;
	webView.scalesPageToFit = YES;
	webView.userInteractionEnabled = YES;
	webView.allowsInlineMediaPlayback = YES;
	webView.mediaPlaybackAllowsAirPlay = NO;
	webView.mediaPlaybackRequiresUserAction = NO;
	webView.contentMode = UIViewContentModeScaleAspectFit;
	webView.backgroundColor = [UIColor whiteColor];
	
	webView.scrollView.minimumZoomScale = 1.0;
	webView.scrollView.maximumZoomScale = 1.0;
	webView.scrollView.scrollEnabled = NO;
	webView.scrollView.bounces = NO;
	_presentWebView = webView;
  }
  
  return _presentWebView;
}

- (NSURL *)applicationSupportDirectory;
{
  NSURL *URL = [[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] lastObject];
  
  if ( ![[NSFileManager defaultManager] fileExistsAtPath:URL.path] ) {
	[[NSFileManager defaultManager] createDirectoryAtURL:URL withIntermediateDirectories:YES attributes:nil error:nil];
  }
  return URL;
}

- (NSURL *)contentURL;
{
  if ( !_contentURL ) {
	// Directory in archive should match archive filename
	NSString *unzipPath  = self.applicationSupportDirectory.path;
	unzipPath = [unzipPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/index.html", ARCHIEVE_NAME]];
	_contentURL = [NSURL fileURLWithPath:unzipPath];
  }
  return _contentURL;
}

- (void)viewDidLoad;
{
  [super viewDidLoad];
  
  if ( [[NSFileManager defaultManager] fileExistsAtPath:self.contentURL.path] ) {
	[self loadContent];
	[self.activityIndicator stopAnimating];
  }
}

- (void)viewDidAppear:(BOOL)animated;
{
  [super viewDidAppear:animated];
  
  self.presentWebView.frame = self.hostView.bounds;
  [self.hostView addSubview:self.presentWebView];
}

- (void)loadContent;
{
  NSURLRequest *request = [NSURLRequest requestWithURL:self.contentURL];
  [self.presentWebView loadRequest:request];
}

- (IBAction)reloadContent:(id)sender;
{
  [self loadContent];
}

- (IBAction)unzipArchive:(id)sender;
{
  [self.activityIndicator startAnimating];

  dispatch_queue_t queue = dispatch_queue_create("unzip", 0);
  
  dispatch_async(queue, ^{
	
	NSURL *url = self.applicationSupportDirectory;
	
	NSString *originalPath = [[NSBundle mainBundle] pathForResource:ARCHIEVE_NAME ofType:@"zip"];
	NSString *unzipPath  = url.path;
	
	ZipArchive *zip = [[ZipArchive alloc] init];
	
	// Open archive
	if ( [zip UnzipOpenFile:originalPath] ) {
	  // Unzip
	  
	  if ( ![[NSFileManager defaultManager] fileExistsAtPath:unzipPath] ) {
		[[NSFileManager defaultManager] createDirectoryAtPath:unzipPath withIntermediateDirectories:YES attributes:nil error:nil];
	  }
	  
	  if ( [zip UnzipFileTo:unzipPath overWrite:YES] ) {
		NSLog(@"unzipped");
	  }
	  // And close
	  [zip UnzipCloseFile];
	}
	
	dispatch_async(dispatch_get_main_queue(), ^{
	  UIAlertView *alerView = [[UIAlertView alloc] initWithTitle:@"Archive" message:@"Archive unzupped" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	  [alerView show];
	  [self loadContent];
	  [self.activityIndicator stopAnimating];
	});
	
  });
}

- (IBAction)enableOption:(id)sender;
{
  UISwitch *sw = (UISwitch *)sender;
  self.presentWebView.mediaPlaybackRequiresUserAction = sw.isOn;

//  [self loadContent];
}

@end
