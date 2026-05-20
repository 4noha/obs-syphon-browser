#import <AppKit/AppKit.h>

#include "syphon-preview-tile.hpp"
#include "syphon-client.hpp"
#include <plugin-support.h>

#include <obs.h>
#include <obs-frontend-api.h>
#include <graphics/graphics.h>
#include <graphics/matrix4.h>
#include <graphics/vec4.h>

#include <QHideEvent>
#include <QLabel>
#include <QPushButton>
#include <QResizeEvent>
#include <QShowEvent>
#include <QVBoxLayout>

#include <algorithm>

namespace {
// A QWidget with a native window handle suitable for OBS to render into via
// obs_display_t. We disable Qt's own painting so OBS owns the surface.
class NativeSurfaceWidget : public QWidget {
public:
	explicit NativeSurfaceWidget(QWidget *parent) : QWidget(parent)
	{
		setAttribute(Qt::WA_NativeWindow);
		setAttribute(Qt::WA_PaintOnScreen);
		setAttribute(Qt::WA_OpaquePaintEvent);
		setAttribute(Qt::WA_DontCreateNativeAncestors);
		setMinimumSize(160, 90);
	}
	QPaintEngine *paintEngine() const override { return nullptr; }
};
} // namespace

SyphonPreviewTile::SyphonPreviewTile(const SyphonServerInfo &info, QWidget *parent)
	: QFrame(parent), m_info(info)
{
	setFrameShape(QFrame::StyledPanel);

	auto *root = new QVBoxLayout(this);
	root->setContentsMargins(4, 4, 4, 4);

	QString title = info.appName;
	if (!info.serverName.isEmpty() && info.serverName != info.appName)
		title += QStringLiteral(" — ") + info.serverName;
	m_titleLabel = new QLabel(title, this);
	m_titleLabel->setStyleSheet(QStringLiteral("font-weight: bold;"));
	root->addWidget(m_titleLabel);

	m_previewSurface = new NativeSurfaceWidget(this);
	root->addWidget(m_previewSurface, 1);

	m_addButton = new QPushButton(tr("Add to current scene"), this);
	connect(m_addButton, &QPushButton::clicked, this, &SyphonPreviewTile::onAddToScene);
	root->addWidget(m_addButton);

	m_source = new SyphonTextureSource(m_info.uuid);
}

SyphonPreviewTile::~SyphonPreviewTile()
{
	destroyDisplay();
	delete m_source;
}

void SyphonPreviewTile::showEvent(QShowEvent *e)
{
	QFrame::showEvent(e);
	if (!m_display)
		initDisplay();
}

void SyphonPreviewTile::hideEvent(QHideEvent *e)
{
	QFrame::hideEvent(e);
	destroyDisplay();
}

void SyphonPreviewTile::resizeEvent(QResizeEvent *e)
{
	QFrame::resizeEvent(e);
	if (m_display) {
		qreal dpr = m_previewSurface->devicePixelRatioF();
		QSize sz = m_previewSurface->size() * dpr;
		obs_display_resize(m_display, sz.width(), sz.height());
	}
}

void SyphonPreviewTile::initDisplay()
{
	// Force the native window handle to exist.
	WId wid = m_previewSurface->winId();
	if (!wid)
		return;

	qreal dpr = m_previewSurface->devicePixelRatioF();
	QSize sz = m_previewSurface->size() * dpr;

	gs_init_data info = {};
	info.cx = sz.width();
	info.cy = sz.height();
	info.format = GS_BGRA;
	info.zsformat = GS_ZS_NONE;
	info.num_backbuffers = 1;
	// On macOS, WId is a pointer to an NSView. obs's gs_window.view is `id`.
	info.window.view = (__bridge NSView *)reinterpret_cast<void *>(wid);

	m_display = obs_display_create(&info, 0);
	if (!m_display) {
		obs_log(LOG_WARNING, "obs_display_create failed for tile");
		return;
	}
	obs_display_add_draw_callback(m_display, onRender, this);
}

void SyphonPreviewTile::destroyDisplay()
{
	if (!m_display)
		return;
	obs_display_remove_draw_callback(m_display, onRender, this);
	obs_display_destroy(m_display);
	m_display = nullptr;
}

void SyphonPreviewTile::onRender(void *param, uint32_t cx, uint32_t cy)
{
	auto *self = static_cast<SyphonPreviewTile *>(param);
	if (!self)
		return;

	// Clear backdrop.
	struct vec4 clear;
	vec4_set(&clear, 0.10f, 0.10f, 0.10f, 1.0f);
	gs_clear(GS_CLEAR_COLOR, &clear, 0.0f, 0);

	gs_texture_t *tex = self->m_source ? self->m_source->acquireTexture() : nullptr;
	if (!tex)
		return;

	const uint32_t tw = gs_texture_get_width(tex);
	const uint32_t th = gs_texture_get_height(tex);
	if (!tw || !th)
		return;

	// Aspect-fit into (cx, cy).
	const float scale = std::min(float(cx) / float(tw), float(cy) / float(th));
	const float dw = float(tw) * scale;
	const float dh = float(th) * scale;
	const float dx = (float(cx) - dw) * 0.5f;
	const float dy = (float(cy) - dh) * 0.5f;

	gs_projection_push();
	gs_ortho(0.0f, float(cx), 0.0f, float(cy), -100.0f, 100.0f);
	gs_set_viewport(0, 0, cx, cy);

	gs_matrix_push();
	gs_matrix_identity();
	gs_matrix_translate3f(dx, dy, 0.0f);
	gs_matrix_scale3f(scale, scale, 1.0f);

	gs_effect_t *eff = obs_get_base_effect(OBS_EFFECT_DEFAULT);
	gs_eparam_t *image = gs_effect_get_param_by_name(eff, "image");
	gs_effect_set_texture(image, tex);
	while (gs_effect_loop(eff, "Draw"))
		gs_draw_sprite(tex, 0, tw, th);

	gs_matrix_pop();
	gs_projection_pop();
}

void SyphonPreviewTile::onAddToScene()
{
	obs_source_t *scene_src = obs_frontend_get_current_scene();
	if (!scene_src)
		return;
	obs_scene_t *scene = obs_scene_from_source(scene_src);
	if (!scene) {
		obs_source_release(scene_src);
		return;
	}

	obs_data_t *settings = obs_data_create();
	// Settings keys come from OBS's mac-syphon plugin. Pass everything we have;
	// the source resolves by UUID first, falling back to name+app.
	obs_data_set_string(settings, "uuid", m_info.uuid.toUtf8().constData());
	obs_data_set_string(settings, "application", m_info.appName.toUtf8().constData());
	obs_data_set_string(settings, "name", m_info.serverName.toUtf8().constData());

	QString srcName = m_info.appName;
	if (!m_info.serverName.isEmpty())
		srcName += QStringLiteral(" / ") + m_info.serverName;

	obs_source_t *src = obs_source_create("syphon-input",
					      srcName.toUtf8().constData(),
					      settings, nullptr);
	if (src) {
		obs_scene_add(scene, src);
		obs_source_release(src);
		obs_log(LOG_INFO, "added Syphon source to current scene: %s",
			srcName.toUtf8().constData());
	} else {
		obs_log(LOG_WARNING, "failed to create syphon-input source");
	}

	obs_data_release(settings);
	obs_source_release(scene_src);
}
