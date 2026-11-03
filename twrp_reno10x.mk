# Copyright (C) 2019 The LineageOS Project
# Copyright (C) 2026 KAI-Miru
# SPDX-License-Identifier: Apache-2.0
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, vendor/twrp/config/common.mk)
$(call inherit-product, device/oppo/reno10x/device.mk)
PRODUCT_NAME := twrp_reno10x
PRODUCT_DEVICE := reno10x
PRODUCT_BRAND := OPPO
PRODUCT_MODEL := OPPO Reno 10x Zoom
PRODUCT_MANUFACTURER := OPPO
PRODUCT_RELEASE_NAME := reno10x
AERA_MAINTAINER := KAI-Miru
TARGET_OTA_ASSERT_DEVICE := reno10x,CPH1919
