# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2024-2025

include $(TOPDIR)/rules.mk

PKG_NAME:=rpicam-apps
PKG_VERSION:=1.11.0
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/raspberrypi/rpicam-apps.git
PKG_SOURCE_DATE:=2025-12-18
PKG_SOURCE_VERSION:=d92a65175b4b553d7b606fcf4fd64dd3275fff09
PKG_MIRROR_HASH:=skip

PKG_MAINTAINER:=Nicholas Balasus
PKG_LICENSE:=BSD-2-Clause
PKG_LICENSE_FILES:=license.txt

PKG_BUILD_DEPENDS:=libcamera boost

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/meson.mk

define Package/rpicam-apps
	SECTION:=multimedia
	CATEGORY:=Multimedia
	DEPENDS:=+libcamera +boost +boost-program_options +libjpeg +libpng +libexif +libstdcpp
	TITLE:=Raspberry Pi camera applications
	URL:=https://github.com/raspberrypi/rpicam-apps
endef

define Package/rpicam-apps/description
	rpicam-apps is a suite of libcamera-based applications for
	Raspberry Pi cameras. Includes rpicam-vid for video capture
	and rpicam-still for still image capture.

	This is a minimal headless build suitable for streaming
	raw video to ffmpeg for encoding.
endef

# Minimal headless build - disable GUI features
# Note: enable_imx500 is boolean (true/false), others are features (enabled/disabled)
MESON_ARGS += \
	-Denable_libav=disabled \
	-Denable_drm=disabled \
	-Denable_egl=disabled \
	-Denable_qt=disabled \
	-Denable_opencv=disabled \
	-Denable_tflite=disabled \
	-Denable_hailo=disabled \
	-Denable_imx500=false

define Package/rpicam-apps/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/rpicam-vid $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/rpicam-still $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/rpicam-hello $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/rpicam-raw $(1)/usr/bin/
endef

$(eval $(call BuildPackage,rpicam-apps))
