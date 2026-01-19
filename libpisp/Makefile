# SPDX-License-Identifier: GPL-2.0-or-later

include $(TOPDIR)/rules.mk

PKG_NAME:=libpisp
PKG_VERSION:=1.2.1
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/raspberrypi/libpisp.git
PKG_SOURCE_VERSION:=v$(PKG_VERSION)
PKG_MIRROR_HASH:=skip

PKG_MAINTAINER:=Nicholas Balasus
PKG_LICENSE:=BSD-2-Clause
PKG_LICENSE_FILES:=LICENSE

PKG_BUILD_DEPENDS:=python3/host

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/meson.mk

define Package/libpisp
	SECTION:=libs
	CATEGORY:=Libraries
	DEPENDS:=+libstdcpp
	TITLE:=Raspberry Pi ISP (PiSP) library
	URL:=https://github.com/raspberrypi/libpisp
endef

define Package/libpisp/description
	Helper library to generate run-time configuration for the
	Raspberry Pi ISP (PiSP), consisting of the Frontend and
	Backend hardware components found on Pi 5.
endef

MESON_ARGS += \
	-Dlogging=disabled \
	-Dexamples=false

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include
	$(CP) $(PKG_INSTALL_DIR)/usr/include/* $(1)/usr/include/
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/lib*.so* $(1)/usr/lib/
	$(INSTALL_DIR) $(1)/usr/lib/pkgconfig
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/pkgconfig/*.pc $(1)/usr/lib/pkgconfig/
	$(INSTALL_DIR) $(1)/usr/share/libpisp
	$(CP) $(PKG_INSTALL_DIR)/usr/share/libpisp/* $(1)/usr/share/libpisp/
endef

define Package/libpisp/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/lib*.so.* $(1)/usr/lib/
	$(INSTALL_DIR) $(1)/usr/share/libpisp
	$(CP) $(PKG_INSTALL_DIR)/usr/share/libpisp/* $(1)/usr/share/libpisp/
endef

$(eval $(call BuildPackage,libpisp))
