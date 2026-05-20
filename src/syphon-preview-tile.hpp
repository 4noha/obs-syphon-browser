#pragma once

#include <QFrame>

#include "syphon-browser-dock.hpp" // SyphonServerInfo

class QLabel;
class QPushButton;
class SyphonTextureSource;

struct obs_display;
typedef struct obs_display obs_display_t;

class SyphonPreviewTile : public QFrame {
	Q_OBJECT
public:
	SyphonPreviewTile(const SyphonServerInfo &info, QWidget *parent);
	~SyphonPreviewTile() override;

protected:
	void resizeEvent(QResizeEvent *event) override;
	void showEvent(QShowEvent *event) override;
	void hideEvent(QHideEvent *event) override;

private slots:
	void onAddToScene();

private:
	void initDisplay();
	void destroyDisplay();
	static void onRender(void *param, uint32_t cx, uint32_t cy);

	SyphonServerInfo m_info;
	QLabel *m_titleLabel = nullptr;
	QWidget *m_previewSurface = nullptr;
	QPushButton *m_addButton = nullptr;

	obs_display_t *m_display = nullptr;
	SyphonTextureSource *m_source = nullptr;
};
