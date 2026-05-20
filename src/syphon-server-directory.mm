#import <Foundation/Foundation.h>

#include "syphon-server-directory.hpp"
#include <obs.h>
#include <plugin-support.h>

#if HAVE_SYPHON_FRAMEWORK
#import <Syphon/Syphon.h>
#endif

namespace {
QString nsToQ(NSString *s)
{
	return s ? QString::fromUtf8([s UTF8String]) : QString();
}
} // namespace

class SyphonDirectoryWatcherPrivate {
public:
#if HAVE_SYPHON_FRAMEWORK
	id<NSObject> obsAdd = nil;
	id<NSObject> obsRetire = nil;
	id<NSObject> obsUpdate = nil;
#endif
};

SyphonDirectoryWatcher::SyphonDirectoryWatcher(QObject *parent)
	: QObject(parent), d(new SyphonDirectoryWatcherPrivate)
{
}

SyphonDirectoryWatcher::~SyphonDirectoryWatcher()
{
	stop();
	delete d;
}

void SyphonDirectoryWatcher::start()
{
#if HAVE_SYPHON_FRAMEWORK
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	NSOperationQueue *q = [NSOperationQueue mainQueue];

	auto handler = ^(NSNotification *) {
		this->refresh();
	};

	d->obsAdd = [nc addObserverForName:SyphonServerAnnounceNotification
					object:nil
					 queue:q
				    usingBlock:handler];
	d->obsRetire = [nc addObserverForName:SyphonServerRetireNotification
					   object:nil
					    queue:q
				       usingBlock:handler];
	d->obsUpdate = [nc addObserverForName:SyphonServerUpdateNotification
					   object:nil
					    queue:q
				       usingBlock:handler];
	refresh();
#else
	obs_log(LOG_WARNING,
		"Syphon framework not linked; server discovery disabled");
	emit serversChanged({});
#endif
}

void SyphonDirectoryWatcher::stop()
{
#if HAVE_SYPHON_FRAMEWORK
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	if (d->obsAdd) {
		[nc removeObserver:d->obsAdd];
		d->obsAdd = nil;
	}
	if (d->obsRetire) {
		[nc removeObserver:d->obsRetire];
		d->obsRetire = nil;
	}
	if (d->obsUpdate) {
		[nc removeObserver:d->obsUpdate];
		d->obsUpdate = nil;
	}
#endif
}

void SyphonDirectoryWatcher::refresh()
{
	QVector<SyphonServerInfo> result;
#if HAVE_SYPHON_FRAMEWORK
	NSArray<NSDictionary *> *servers =
		[[SyphonServerDirectory sharedDirectory] servers];
	for (NSDictionary *s in servers) {
		SyphonServerInfo info;
		info.uuid = nsToQ(s[SyphonServerDescriptionUUIDKey]);
		info.appName = nsToQ(s[SyphonServerDescriptionAppNameKey]);
		info.serverName = nsToQ(s[SyphonServerDescriptionNameKey]);
		result.push_back(info);
	}
#endif
	emit serversChanged(result);
}
