/*
Syphon Browser for OBS
Copyright (C) 2026 4noha <nokkii.03@gmail.com>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
*/

#include <obs-module.h>
#include <obs-frontend-api.h>
#include <plugin-support.h>

#include <QMainWindow>

#include "syphon-browser-dock.hpp"

OBS_DECLARE_MODULE()
OBS_MODULE_USE_DEFAULT_LOCALE(PLUGIN_NAME, "en-US")

extern "C" {
MODULE_EXPORT const char *obs_module_name(void)
{
	return "Syphon Browser";
}

MODULE_EXPORT const char *obs_module_description(void)
{
	return "Browse and preview Syphon servers in a dock without putting them on air.";
}
}

namespace {
SyphonBrowserDock *g_dock = nullptr;

void onFrontendEvent(enum obs_frontend_event event, void *)
{
	if (event != OBS_FRONTEND_EVENT_FINISHED_LOADING)
		return;

	auto *main = static_cast<QMainWindow *>(obs_frontend_get_main_window());
	if (!main) {
		obs_log(LOG_WARNING, "main window unavailable; dock not registered");
		return;
	}
	if (g_dock)
		return;

	g_dock = new SyphonBrowserDock(main);
	g_dock->setObjectName("SyphonBrowserDock");
	obs_frontend_add_dock_by_id(
		"obs-syphon-browser-dock",
		obs_module_text("SyphonBrowser.Title"),
		g_dock);
}
} // namespace

bool obs_module_load(void)
{
	obs_log(LOG_INFO, "loading (v%s)", PLUGIN_VERSION);
	obs_frontend_add_event_callback(onFrontendEvent, nullptr);
	return true;
}

void obs_module_unload(void)
{
	obs_frontend_remove_event_callback(onFrontendEvent, nullptr);
	// Dock is parented to the main window; Qt cleans up on shutdown.
	g_dock = nullptr;
	obs_log(LOG_INFO, "unloaded");
}
