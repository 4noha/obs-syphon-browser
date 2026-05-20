#pragma once

#include <QFrame>
#include <QString>
#include <QVector>

class QGridLayout;
class QLabel;
class QScrollArea;
class SyphonDirectoryWatcher;
class SyphonPreviewTile;

struct SyphonServerInfo {
	QString uuid;
	QString appName;
	QString serverName;
};

class SyphonBrowserDock : public QFrame {
	Q_OBJECT
public:
	explicit SyphonBrowserDock(QWidget *parent = nullptr);
	~SyphonBrowserDock() override;

private slots:
	void onServersChanged(const QVector<SyphonServerInfo> &servers);

private:
	void relayout();

	QLabel *m_statusLabel = nullptr;
	QScrollArea *m_scroll = nullptr;
	QWidget *m_grid = nullptr;
	QGridLayout *m_gridLayout = nullptr;
	QVector<SyphonServerInfo> m_servers;
	QVector<SyphonPreviewTile *> m_tiles;
	SyphonDirectoryWatcher *m_watcher = nullptr;
};
