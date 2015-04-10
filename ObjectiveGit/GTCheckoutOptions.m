//
//  GTCheckoutOptions.m
//  ObjectiveGitFramework
//
//  Created by Etienne on 10/04/2015.
//  Copyright (c) 2015 GitHub, Inc. All rights reserved.
//

#import "GTCheckoutOptions.h"
#import "GTDiffFile.h"
#import "NSError+Git.h"
#import "git2.h"

// The type of block passed to -checkout:strategy:progressBlock:notifyBlock:notifyFlags:error: for progress reporting
typedef void (^GTCheckoutProgressBlock)(NSString *path, NSUInteger completedSteps, NSUInteger totalSteps);

// The type of block passed to -checkout:strategy:progressBlock:notifyBlock:notifyFlags:error: for notification reporting
typedef int  (^GTCheckoutNotifyBlock)(GTCheckoutNotifyFlags why, NSString *path, GTDiffFile *baseline, GTDiffFile *target, GTDiffFile *workdir);


@interface GTCheckoutOptions () {
	git_checkout_options _git_checkoutOptions;
}
@end

@implementation GTCheckoutOptions

+ (instancetype)checkoutOptionsWithStrategy:(GTCheckoutStrategyType)strategy notifyFlags:(GTCheckoutNotifyFlags)notifyFlags progressBlock:(GTCheckoutProgressBlock)progressBlock notifyBlock:(GTCheckoutNotifyBlock)notifyBlock {
	GTCheckoutOptions *options = [self checkoutOptionsWithStrategy:strategy progressBlock:progressBlock];
	options.notifyFlags = notifyFlags;
	options.notifyBlock = notifyBlock;
	return options;
}

+ (instancetype)checkoutOptionsWithStrategy:(GTCheckoutStrategyType)strategy progressBlock:(GTCheckoutProgressBlock)progressBlock {
	GTCheckoutOptions *options = [self checkoutOptionsWithStrategy:strategy];
	options.progressBlock = progressBlock;
	return options;
}

+ (instancetype)checkoutOptionsWithStrategy:(GTCheckoutStrategyType)strategy {
	GTCheckoutOptions *options = [[self alloc] init];
	options.strategy = strategy;
	return options;
}

- (instancetype)init {
	self = [super init];
	if (self == nil) return nil;

	_git_checkoutOptions.version = GIT_CHECKOUT_OPTIONS_VERSION;
	
	return self;
}

static void GTCheckoutProgressCallback(const char *path, size_t completedSteps, size_t totalSteps, void *payload) {
	if (payload == NULL) return;
	void (^block)(NSString *, NSUInteger, NSUInteger) = (__bridge id)payload;
	NSString *nsPath = (path != NULL ? [NSString stringWithUTF8String:path] : nil);
	block(nsPath, completedSteps, totalSteps);
}

static int GTCheckoutNotifyCallback(git_checkout_notify_t why, const char *path, const git_diff_file *baseline, const git_diff_file *target, const git_diff_file *workdir, void *payload) {
	if (payload == NULL) return 0;
	GTCheckoutNotifyBlock block = (__bridge id)payload;
	NSString *nsPath = (path != NULL ? @(path) : nil);
	GTDiffFile *gtBaseline = (baseline != NULL ? [[GTDiffFile alloc] initWithGitDiffFile:*baseline] : nil);
	GTDiffFile *gtTarget = (target != NULL ? [[GTDiffFile alloc] initWithGitDiffFile:*target] : nil);
	GTDiffFile *gtWorkdir = (workdir != NULL ? [[GTDiffFile alloc] initWithGitDiffFile:*workdir] : nil);
	return block((GTCheckoutNotifyFlags)why, nsPath, gtBaseline, gtTarget, gtWorkdir);
}

- (git_checkout_options *)git_checkoutOptions {
	_git_checkoutOptions.checkout_strategy = self.strategy;

	if (self.progressBlock) {
		_git_checkoutOptions.progress_cb = GTCheckoutProgressCallback;
		_git_checkoutOptions.progress_payload = (__bridge void *)self.progressBlock;
	}

	if (self.notifyBlock) {
		_git_checkoutOptions.notify_cb = GTCheckoutNotifyCallback;
		_git_checkoutOptions.notify_flags = self.notifyFlags;
		_git_checkoutOptions.notify_payload = (__bridge void *)self.notifyBlock;
	}

	return &_git_checkoutOptions;
}

@end
