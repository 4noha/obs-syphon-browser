cmake_minimum_required(VERSION 3.28...3.30)

include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/common/bootstrap.cmake" NO_POLICY_SCOPE)

project(${_name} VERSION ${_version} LANGUAGES C CXX)

# This plugin always needs Qt + frontend-api. Force on regardless of preset.
set(ENABLE_FRONTEND_API ON CACHE BOOL "Use obs-frontend-api for UI functionality" FORCE)
set(ENABLE_QT ON CACHE BOOL "Use Qt functionality" FORCE)

include(compilerconfig)
include(defaults)
include(helpers)

# Enable Objective-C++ on macOS for Syphon / Cocoa interop.
if(APPLE)
  enable_language(OBJC)
  enable_language(OBJCXX)
endif()

add_library(${CMAKE_PROJECT_NAME} MODULE)

find_package(libobs REQUIRED)
target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE OBS::libobs)

find_package(obs-frontend-api REQUIRED)
target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE OBS::obs-frontend-api)

find_package(Qt6 COMPONENTS Widgets Core REQUIRED)
target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE Qt6::Core Qt6::Widgets)
target_compile_options(
  ${CMAKE_PROJECT_NAME}
  PRIVATE $<$<C_COMPILER_ID:Clang,AppleClang>:-Wno-quoted-include-in-framework-header -Wno-comma>
)
set_target_properties(
  ${CMAKE_PROJECT_NAME}
  PROPERTIES
    AUTOMOC ON
    AUTOUIC ON
    AUTORCC ON
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
)

target_sources(
  ${CMAKE_PROJECT_NAME}
  PRIVATE
    src/plugin-main.cpp
    src/syphon-browser-dock.hpp
    src/syphon-browser-dock.cpp
    src/syphon-preview-tile.hpp
)

# Preview tile is .mm because gs_init_data.window.view on macOS is an
# Objective-C `id` (NSView *).
if(APPLE)
  target_sources(${CMAKE_PROJECT_NAME} PRIVATE src/syphon-preview-tile.mm)
else()
  target_sources(${CMAKE_PROJECT_NAME} PRIVATE src/syphon-preview-tile.cpp)
endif()

if(APPLE)
  # The Qt6 prebuilt's .prl files list AGL as a required framework, but AGL
  # was removed from the macOS 14+ SDK. Build a stub AGL.framework with an
  # empty dylib so the linker can resolve `-framework AGL`. We don't call
  # any AGL symbols, so the stub is sufficient.
  set(AGL_STUB_DIR "${CMAKE_BINARY_DIR}/agl-stub")
  set(AGL_STUB_FW "${AGL_STUB_DIR}/AGL.framework")
  if(NOT EXISTS "${AGL_STUB_FW}/AGL")
    file(MAKE_DIRECTORY "${AGL_STUB_FW}/Versions/A/Headers")
    file(MAKE_DIRECTORY "${AGL_STUB_FW}/Versions/A/Resources")
    set(AGL_STUB_C "${AGL_STUB_DIR}/agl_stub.c")
    file(WRITE "${AGL_STUB_C}" "")
    execute_process(
      COMMAND
        clang -dynamiclib -x c "${AGL_STUB_C}"
        -arch arm64 -arch x86_64
        -mmacosx-version-min=12.0
        -install_name "@rpath/AGL.framework/Versions/A/AGL"
        -o "${AGL_STUB_FW}/Versions/A/AGL"
      COMMAND_ERROR_IS_FATAL ANY
    )
    execute_process(COMMAND ln -sf A "${AGL_STUB_FW}/Versions/Current")
    execute_process(COMMAND ln -sf Versions/Current/AGL "${AGL_STUB_FW}/AGL")
    execute_process(COMMAND ln -sf Versions/Current/Headers "${AGL_STUB_FW}/Headers")
    file(
      WRITE "${AGL_STUB_FW}/Versions/A/Resources/Info.plist"
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<plist version=\"1.0\"><dict>
<key>CFBundleName</key><string>AGL</string>
<key>CFBundleIdentifier</key><string>com.apple.AGL.stub</string>
<key>CFBundleExecutable</key><string>AGL</string>
<key>CFBundleVersion</key><string>1</string>
</dict></plist>
"
    )
  endif()
  target_link_directories(${CMAKE_PROJECT_NAME} PRIVATE "${AGL_STUB_DIR}")
  target_link_options(${CMAKE_PROJECT_NAME} PRIVATE "-F${AGL_STUB_DIR}")

  target_sources(
    ${CMAKE_PROJECT_NAME}
    PRIVATE
      src/syphon-client.hpp
      src/syphon-client.mm
      src/syphon-server-directory.hpp
      src/syphon-server-directory.mm
  )

  find_library(COCOA_LIBRARY Cocoa REQUIRED)
  find_library(IOSURFACE_LIBRARY IOSurface REQUIRED)
  find_library(QUARTZCORE_LIBRARY QuartzCore REQUIRED)
  target_link_libraries(
    ${CMAKE_PROJECT_NAME}
    PRIVATE
      ${COCOA_LIBRARY}
      ${IOSURFACE_LIBRARY}
      ${QUARTZCORE_LIBRARY}
  )

  # Syphon framework integration. Vendor a prebuilt Syphon.framework into
  # vendor/SyphonFramework/ to enable. Without it we compile a stub that
  # surfaces "no Syphon framework" in the dock so the rest of the plugin
  # remains testable.
  set(SYPHON_FRAMEWORK_DIR "${CMAKE_CURRENT_SOURCE_DIR}/vendor/SyphonFramework")
  if(EXISTS "${SYPHON_FRAMEWORK_DIR}/Syphon.framework")
    target_link_libraries(
      ${CMAKE_PROJECT_NAME}
      PRIVATE "${SYPHON_FRAMEWORK_DIR}/Syphon.framework"
    )
    target_include_directories(
      ${CMAKE_PROJECT_NAME}
      PRIVATE "${SYPHON_FRAMEWORK_DIR}/Syphon.framework/Headers"
    )
    target_compile_definitions(${CMAKE_PROJECT_NAME} PRIVATE HAVE_SYPHON_FRAMEWORK=1)
    message(STATUS "Syphon Browser: using vendored Syphon.framework")
  else()
    message(
      WARNING
      "Syphon.framework not found at ${SYPHON_FRAMEWORK_DIR}. "
      "Building stub Syphon client. See vendor/README.md to enable."
    )
    target_compile_definitions(${CMAKE_PROJECT_NAME} PRIVATE HAVE_SYPHON_FRAMEWORK=0)
  endif()
endif()

set_target_properties_plugin(${CMAKE_PROJECT_NAME} PROPERTIES OUTPUT_NAME ${_name})
