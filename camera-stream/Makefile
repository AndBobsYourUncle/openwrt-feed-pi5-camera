# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2024-2025

include $(TOPDIR)/rules.mk

PKG_NAME:=camera-stream
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=Nicholas Balasus
PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/camera-stream
	SECTION:=multimedia
	CATEGORY:=Multimedia
	DEPENDS:=+rpicam-apps +mediamtx +ffmpeg
	TITLE:=Camera RTSP streaming service
	URL:=https://github.com/AndBobsYourUncle/openwrt-feed-pi5-camera
	PKGARCH:=all
endef

define Package/camera-stream/description
	Automatic RTSP streaming service for Raspberry Pi cameras.
	Streams camera video to mediamtx RTSP server on boot.

	Auto-detects Pi 4 (hardware H.264) vs Pi 5 (software libx264)
	and uses the appropriate encoder.

	After installing, enable with:
	  /etc/init.d/camera-stream enable
	  /etc/init.d/camera-stream start
endef

define Build/Compile
	# Nothing to compile - shell scripts only
endef

define Package/camera-stream/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/camera-stream.sh $(1)/usr/bin/
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/camera-stream.init $(1)/etc/init.d/camera-stream
endef

$(eval $(call BuildPackage,camera-stream))
