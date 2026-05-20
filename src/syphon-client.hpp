#pragma once

#include <QString>

struct gs_texture;
typedef struct gs_texture gs_texture_t;

class SyphonTextureSourcePrivate;

// Pulls frames from a single Syphon server (by UUID) and exposes the latest
// frame as a gs_texture_t* suitable for drawing to an obs_display_t. Must be
// invoked on the OBS graphics thread (the obs_display render callback).
//
// With the Syphon framework absent at build time, acquireTexture() always
// returns nullptr.
class SyphonTextureSource {
public:
	explicit SyphonTextureSource(const QString &uuid);
	~SyphonTextureSource();

	// Returns the latest frame as a gs_texture_t* or nullptr if no frame is
	// available yet. The texture is owned by this object and is invalidated
	// by the next acquireTexture() call.
	gs_texture_t *acquireTexture();

private:
	SyphonTextureSourcePrivate *d = nullptr;
};
