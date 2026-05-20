#pragma once

#include <QObject>
#include <QVector>

#include "syphon-browser-dock.hpp" // SyphonServerInfo

class SyphonDirectoryWatcherPrivate;

// Watches the macOS-wide Syphon server registry and emits serversChanged
// whenever a server is announced, retires, or updates. With the Syphon
// framework absent at build time, emits an empty list and stays idle.
class SyphonDirectoryWatcher : public QObject {
	Q_OBJECT
public:
	explicit SyphonDirectoryWatcher(QObject *parent = nullptr);
	~SyphonDirectoryWatcher() override;

	void start();
	void stop();

signals:
	void serversChanged(const QVector<SyphonServerInfo> &servers);

private:
	void refresh();
	SyphonDirectoryWatcherPrivate *d = nullptr;
};
