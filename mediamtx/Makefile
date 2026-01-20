# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2024-2025

include $(TOPDIR)/rules.mk

PKG_NAME:=mediamtx
PKG_VERSION:=1.15.6
PKG_RELEASE:=1

PKG_SOURCE:=mediamtx_v$(PKG_VERSION)_linux_arm64.tar.gz
PKG_SOURCE_URL:=https://github.com/bluenviron/mediamtx/releases/download/v$(PKG_VERSION)/
PKG_HASH:=skip

PKG_MAINTAINER:=Nicholas Balasus
PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE

include $(INCLUDE_DIR)/package.mk

define Package/mediamtx
	SECTION:=multimedia
	CATEGORY:=Multimedia
	TITLE:=MediaMTX RTSP/RTMP/HLS/WebRTC server
	URL:=https://github.com/bluenviron/mediamtx
	DEPENDS:=@(aarch64||arm)
endef

define Package/mediamtx/description
	MediaMTX (formerly rtsp-simple-server) is a ready-to-use and
	zero-dependency real-time media server and media proxy that
	allows to publish, read, proxy, record and playback video and
	audio streams.
endef

define Build/Compile
	# Pre-built binary, nothing to compile
endef

define Package/mediamtx/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/mediamtx $(1)/usr/bin/
	$(INSTALL_DIR) $(1)/etc/mediamtx
	$(INSTALL_CONF) $(PKG_BUILD_DIR)/mediamtx.yml $(1)/etc/mediamtx/
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/mediamtx.init $(1)/etc/init.d/mediamtx
endef

define Package/mediamtx/conffiles
/etc/mediamtx/mediamtx.yml
endef

$(eval $(call BuildPackage,mediamtx))
