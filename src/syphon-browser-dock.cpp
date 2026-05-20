#include "syphon-browser-dock.hpp"
#include "syphon-preview-tile.hpp"
#include "syphon-server-directory.hpp"
#include <plugin-support.h>

#include <QGridLayout>
#include <QLabel>
#include <QScrollArea>
#include <QVBoxLayout>

SyphonBrowserDock::SyphonBrowserDock(QWidget *parent) : QFrame(parent)
{
	auto *root = new QVBoxLayout(this);
	root->setContentsMargins(8, 8, 8, 8);

	m_statusLabel = new QLabel(tr("Searching for Syphon servers…"), this);
	root->addWidget(m_statusLabel);

	m_scroll = new QScrollArea(this);
	m_scroll->setWidgetResizable(true);
	m_scroll->setFrameShape(QFrame::NoFrame);
	m_grid = new QWidget(m_scroll);
	m_gridLayout = new QGridLayout(m_grid);
	m_gridLayout->setSpacing(8);
	m_gridLayout->setContentsMargins(0, 0, 0, 0);
	m_scroll->setWidget(m_grid);
	root->addWidget(m_scroll, 1);

	m_watcher = new SyphonDirectoryWatcher(this);
	connect(m_watcher, &SyphonDirectoryWatcher::serversChanged, this,
		&SyphonBrowserDock::onServersChanged);
	m_watcher->start();
}

SyphonBrowserDock::~SyphonBrowserDock() = default;

void SyphonBrowserDock::onServersChanged(const QVector<SyphonServerInfo> &servers)
{
	m_servers = servers;
	relayout();
}

void SyphonBrowserDock::relayout()
{
	for (auto *tile : m_tiles)
		tile->deleteLater();
	m_tiles.clear();

	if (m_servers.isEmpty()) {
		m_statusLabel->setText(tr("No Syphon servers running."));
		return;
	}
	m_statusLabel->setText(tr("%1 server(s) found").arg(m_servers.size()));

	const int cols = 2;
	for (int i = 0; i < m_servers.size(); ++i) {
		auto *tile = new SyphonPreviewTile(m_servers[i], m_grid);
		m_tiles.push_back(tile);
		m_gridLayout->addWidget(tile, i / cols, i % cols);
	}
}
