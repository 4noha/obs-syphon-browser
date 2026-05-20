#import <Foundation/Foundation.h>
#import <IOSurface/IOSurface.h>
#import <Metal/Metal.h>

#include "syphon-client.hpp"
#include <plugin-support.h>
#include <obs.h>

#if HAVE_SYPHON_FRAMEWORK
#import <Syphon/Syphon.h>
#endif

class SyphonTextureSourcePrivate {
public:
	QString uuid;
#if HAVE_SYPHON_FRAMEWORK
	SyphonMetalClient *client = nil;
	id<MTLDevice> device = nil;
#endif
	gs_texture_t *texture = nullptr;
	IOSurfaceID lastSurfaceID = 0;
};

namespace {

// Look up the server descriptor by UUID in the directory.
#if HAVE_SYPHON_FRAMEWORK
NSDictionary *findServerByUuid(NSString *uuid)
{
	for (NSDictionary *s in
	     [[SyphonServerDirectory sharedDirectory] servers]) {
		if ([s[SyphonServerDescriptionUUIDKey] isEqualToString:uuid])
			return s;
	}
	return nil;
}
#endif

} // namespace

SyphonTextureSource::SyphonTextureSource(const QString &uuid)
	: d(new SyphonTextureSourcePrivate)
{
	d->uuid = uuid;

#if HAVE_SYPHON_FRAMEWORK
	@autoreleasepool {
		NSString *nsUuid =
			[NSString stringWithUTF8String:uuid.toUtf8().constData()];
		NSDictionary *desc = findServerByUuid(nsUuid);
		if (!desc) {
			obs_log(LOG_WARNING,
				"Syphon server not found: %s",
				uuid.toUtf8().constData());
			return;
		}
		d->device = MTLCreateSystemDefaultDevice();
		if (!d->device) {
			obs_log(LOG_ERROR, "no Metal device available");
			return;
		}
		d->client = [[SyphonMetalClient alloc]
			   initWithServerDescription:desc
					      device:d->device
					     options:nil
				     newFrameHandler:nil];
	}
#endif
}

SyphonTextureSource::~SyphonTextureSource()
{
#if HAVE_SYPHON_FRAMEWORK
	if (d->client) {
		[d->client stop];
		d->client = nil;
	}
	d->device = nil;
#endif
	if (d->texture) {
		gs_texture_destroy(d->texture);
		d->texture = nullptr;
	}
	delete d;
}

gs_texture_t *SyphonTextureSource::acquireTexture()
{
#if HAVE_SYPHON_FRAMEWORK
	if (!d->client)
		return nullptr;

	@autoreleasepool {
		id<MTLTexture> mtlTex = [d->client newFrameImage];
		if (!mtlTex)
			return d->texture; // keep last frame if no new one

		IOSurfaceRef surface = mtlTex.iosurface;
		if (!surface)
			return d->texture;

		IOSurfaceID sid = IOSurfaceGetID(surface);
		if (sid != d->lastSurfaceID || !d->texture) {
			if (d->texture) {
				gs_texture_destroy(d->texture);
				d->texture = nullptr;
			}
			d->texture = gs_texture_create_from_iosurface(surface);
			d->lastSurfaceID = sid;
		}
	}
	return d->texture;
#else
	return nullptr;
#endif
}
