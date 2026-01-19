# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2024-2025

include $(TOPDIR)/rules.mk

PKG_NAME:=libcamera
PKG_VERSION:=0.6.0
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/raspberrypi/libcamera.git
PKG_SOURCE_DATE:=2025-12-02
PKG_SOURCE_VERSION:=f0e40f1c50bd0afe65727d6e407d0dcb42666ada
PKG_MIRROR_HASH:=skip

PKG_MAINTAINER:=Nicholas Balasus
PKG_LICENSE:=LGPL-2.1+ GPL-2.0+ BSD-2-Clause MIT
PKG_LICENSE_FILES:=LICENSES

PKG_BUILD_DEPENDS:= \
	python3/host \
	python-jinja2/host \
	python-ply/host \
	python-yaml/host \
	openssl \
	libevent2 \
	LIBCAMERA_PIPELINE_RPI_PISP:libpisp \
	LIBCAMERA_GSTREAMER_SUPPORT:gstreamer1-libs \
	LIBCAMERA_GSTREAMER_SUPPORT:gst1-plugins-base

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/meson.mk

# Disable stripping - IPA modules require intact ELF symbol info
# that gets corrupted by OpenWrt's strip process
RSTRIP:=:

define Package/libcamera/config
  source "$(SOURCE)/Config.in"
endef

define Package/libcamera
	SECTION:=multimedia
	CATEGORY:=Multimedia
	DEPENDS:=+libyaml +libgnutls +libstdcpp +libudev-zero +libevent2 +libevent2-pthreads +libdrm
	DEPENDS+=$(if $(CONFIG_LIBCAMERA_PIPELINE_RPI_PISP),+libpisp)
	DEPENDS+=$(if $(CONFIG_LIBCAMERA_GSTREAMER_SUPPORT),+gst1-plugins-base +gstreamer1-libs)
	TITLE:=Linux camera framework
	URL:=https://libcamera.org/
endef

define Package/libcamera/description
	libcamera provides a software stack to support complex devices
	that need heavy hardware image processing operations.

	This package includes support for Raspberry Pi cameras on both
	Pi 4 (VC4 pipeline) and Pi 5 (PiSP pipeline).
endef

# Build pipeline list based on config
LIBCAMERA_PIPELINES :=

ifeq ($(CONFIG_LIBCAMERA_PIPELINE_RPI_VC4),y)
	LIBCAMERA_PIPELINES += rpi/vc4
endif
ifeq ($(CONFIG_LIBCAMERA_PIPELINE_RPI_PISP),y)
	LIBCAMERA_PIPELINES += rpi/pisp
endif
ifeq ($(CONFIG_LIBCAMERA_PIPELINE_SIMPLE),y)
	LIBCAMERA_PIPELINES += simple
endif
ifeq ($(CONFIG_LIBCAMERA_PIPELINE_UVCVIDEO),y)
	LIBCAMERA_PIPELINES += uvcvideo
endif

# Convert space-separated list to comma-separated
empty :=
space := $(empty) $(empty)
comma := ,
PIPELINES_ARG := $(subst $(space),$(comma),$(LIBCAMERA_PIPELINES))

MESON_ARGS += \
	-Dpipelines=$(PIPELINES_ARG) \
	-Dv4l2=$(if $(CONFIG_LIBCAMERA_V4L2),enabled,disabled) \
	-Dgstreamer=$(if $(CONFIG_LIBCAMERA_GSTREAMER_SUPPORT),enabled,disabled) \
	-Dandroid=disabled \
	-Ddocumentation=disabled \
	-Dtest=false \
	-Dpycamera=disabled \
	-Dwerror=false \
	-Dcam=enabled \
	-Dqcam=disabled \
	-Dstrip=false

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include
	$(CP) $(PKG_INSTALL_DIR)/usr/include/* $(1)/usr/include/
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/lib*.so* $(1)/usr/lib/
	$(INSTALL_DIR) $(1)/usr/lib/pkgconfig
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/pkgconfig/*.pc $(1)/usr/lib/pkgconfig/
endef

define Package/libcamera/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/cam $(1)/usr/bin/
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/lib*.so.* $(1)/usr/lib/
	$(INSTALL_DIR) $(1)/usr/share/libcamera
	$(CP) $(PKG_INSTALL_DIR)/usr/share/libcamera/* $(1)/usr/share/libcamera/
	$(INSTALL_DIR) $(1)/usr/libexec/libcamera
	$(CP) $(PKG_INSTALL_DIR)/usr/libexec/libcamera/* $(1)/usr/libexec/libcamera/
	$(INSTALL_DIR) $(1)/usr/lib/libcamera
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/libcamera/* $(1)/usr/lib/libcamera/
	$(INSTALL_DIR) $(1)/usr/share/libcamera/ipa
	$(CP) $(PKG_INSTALL_DIR)/usr/share/libcamera/ipa/* $(1)/usr/share/libcamera/ipa/
ifeq ($(CONFIG_LIBCAMERA_GSTREAMER_SUPPORT),y)
	$(INSTALL_DIR) $(1)/usr/lib/gstreamer-1.0
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/gstreamer-1.0/libgstlibcamera.so* $(1)/usr/lib/gstreamer-1.0/
endif
endef

$(eval $(call BuildPackage,libcamera))
