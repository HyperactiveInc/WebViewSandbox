//
//  ViewController.m
//  WebViewSandbox
//
//  Created by Anton Kolchunov on 20.02.15.
//  Copyright (c) 2015 Hyperactive Inc. All rights reserved.
//

#import "ViewController.h"
#import "ZipArchive.h"
#import <WebKit/WebKit.h>

static NSString * const ARCHIEVE_NAME = @"sample-contentitem";

@interface ViewController () <WKNavigationDelegate> {
  
  NSURL *_contentURL;
  
  BOOL _unzipping;

}

@property (nonatomic, assign, getter=isUsingWebKit) BOOL usingWebKit;

@property (nonatomic, weak) IBOutlet UIView *hostView;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *activityIndicator;

@property (nonatomic, strong) UIWebView *webView;
@property (nonatomic, strong) WKWebView *webKitWebView;

@end

@implementation ViewController

- (UIWebView *)webView;
{
  if ( !_webView ) {
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
	_webView = webView;
  }
  
  return _webView;
}

- (WKWebView *)webKitWebView;
{
  if ( !_webKitWebView ) {
	WKUserContentController* userContentController = [[WKUserContentController alloc] init];
	
	WKWebViewConfiguration* configuration = [[WKWebViewConfiguration alloc] init];
	configuration.userContentController = userContentController;
	configuration.allowsInlineMediaPlayback = YES;
	configuration.mediaPlaybackAllowsAirPlay = NO;
	configuration.mediaPlaybackRequiresUserAction = NO;
	
	WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:configuration];
	webView.navigationDelegate = self;
	_webKitWebView = webView;
  }
  return _webKitWebView;
}



- (NSURL *)applicationSupportDirectory;
{
  NSURL *URL = [[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] lastObject];
  
  if ( ![[NSFileManager defaultManager] fileExistsAtPath:URL.path] ) {
	[[NSFileManager defaultManager] createDirectoryAtURL:URL withIntermediateDirectories:YES attributes:nil error:nil];
  }
  return URL;
}

- (NSURL *)applicationTmpDirectory;
{
  NSString *filePath = NSTemporaryDirectory();
  if ( ![[NSFileManager defaultManager] fileExistsAtPath:filePath] ) {
	[[NSFileManager defaultManager] createDirectoryAtPath:filePath withIntermediateDirectories:YES attributes:nil error:nil];
  }
  return [NSURL fileURLWithPath:filePath];
}

- (NSURL *)contentURL;
{
  // Directory in archive should match archive filename
  NSString *unzipPath  = ( self.isUsingWebKit ) ? self.applicationTmpDirectory.path : self.applicationSupportDirectory.path;
  unzipPath = [unzipPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/index.html", ARCHIEVE_NAME]];
  NSURL *contentURL = [NSURL fileURLWithPath:unzipPath];
  return contentURL;
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
  
  self.webView.frame = self.hostView.bounds;
  self.webKitWebView.frame = self.hostView.bounds;
  self.webKitWebView.hidden = YES;
  [self.hostView addSubview:self.webKitWebView];
  [self.hostView addSubview:self.webView];
}

- (void)loadContent;
{
  NSURLRequest *request = [NSURLRequest requestWithURL:self.contentURL];
  UIView *nextWebView = (self.isUsingWebKit ) ? self.webKitWebView : self.webView;
  UIView *currentWebView = (self.isUsingWebKit ) ? self.webView : self.webKitWebView;
  
  nextWebView.alpha = 0.f;
  nextWebView.hidden = NO;
  
  self.isUsingWebKit ? [self.webKitWebView loadRequest:request] : [self.webView loadRequest:request];

  [self.view bringSubviewToFront:nextWebView];

  [UIView animateWithDuration:0.5f animations:^{
	nextWebView.alpha = 1.f;
	currentWebView.alpha = 0.f;
  } completion:^(BOOL finished) {
	currentWebView.hidden = YES;
  }];
}

- (IBAction)reloadContent:(id)sender;
{
  [self loadContent];
}

- (IBAction)unzipArchive:(id)sender;
{
  if ( _unzipping ) {
	return;
  }
  
  _unzipping = YES;
  
  [self.activityIndicator startAnimating];

  
  dispatch_queue_t queue = dispatch_queue_create("unzip", 0);
  
  dispatch_async(queue, ^{
	
	NSURL *url = self.applicationSupportDirectory;
	
	NSString *originalPath = [[NSBundle mainBundle] pathForResource:ARCHIEVE_NAME ofType:@"zip"];
	NSString *unzipPath  = url.path;
	NSString *tempPath = [self.applicationTmpDirectory.path stringByAppendingPathComponent:ARCHIEVE_NAME];
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
	
	if ( [[NSFileManager defaultManager] fileExistsAtPath:tempPath] ) {
	  [[NSFileManager defaultManager] removeItemAtPath:tempPath error:nil];
	}
	
	NSError *error = nil;
	[[NSFileManager defaultManager] copyItemAtPath:[unzipPath stringByAppendingPathComponent:ARCHIEVE_NAME] toPath:tempPath error:&error];
	if ( error ) {
	  NSLog(@"Directory copy error: %@", error.localizedDescription);
	}
	
	dispatch_async(dispatch_get_main_queue(), ^{
	  UIAlertView *alerView = [[UIAlertView alloc] initWithTitle:@"Archive" message:@"Archive unzupped" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	  [alerView show];
	  
	  _unzipping = NO;
	  [self loadContent];
	  [self.activityIndicator stopAnimating];
	});
	
  });
}

- (IBAction)enableOption:(id)sender;
{
  UISwitch *sw = (UISwitch *)sender;
  self.webView.mediaPlaybackRequiresUserAction = sw.isOn;

//  [self loadUIWebViewContent];
}

- (IBAction)useWebKitToggle:(id)sender;
{
  UISwitch *sw = (UISwitch *)sender;
  
  self.usingWebKit = sw.isOn;

  [self loadContent];
}


#pragma mark - WKNavigationDelegate's methods

- (void)webView:(WKWebView *)webView
didFailNavigation:(WKNavigation *)navigation
	  withError:(NSError *)error
{
  NSLog(@"%@", [error localizedDescription]);
//  [self alert:[error localizedDescription]];
}

- (void)webView:(WKWebView *)webView
didFailProvisionalNavigation:(WKNavigation *)navigation
	  withError:(NSError *)error
{
  NSLog(@"%@", [error localizedDescription]);
//  [self alert:[error localizedDescription]];
}

- (void)webView:(WKWebView *)webView
didFinishNavigation:(WKNavigation *)navigation
{
}


- (void)webView:(WKWebView *)webView
decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
  NSLog(@"URL: %@", [navigationAction.request.URL description]);
  decisionHandler(WKNavigationActionPolicyAllow);
}

@end
