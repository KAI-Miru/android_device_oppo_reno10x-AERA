# Copyright (C) 2018-2019 The LineageOS Project
# Copyright (C) 2026 KAI-Miru
# SPDX-License-Identifier: Apache-2.0
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/emulated_storage.mk)
LOCAL_PATH := device/oppo/reno10x
PRODUCT_PLATFORM := msmnile
PRODUCT_SHIPPING_API_LEVEL := 28
AB_OTA_UPDATER := false
AB_OTA_PARTITIONS :=
PRODUCT_USE_DYNAMIC_PARTITIONS := false
PRODUCT_VIRTUAL_AB_OTA := false
PRODUCT_BUILD_SUPER_PARTITION := false
PRODUCT_BUILD_RECOVERY_IMAGE := true
PRODUCT_SOONG_NAMESPACES += $(LOCAL_PATH)
# mkbootfs reads this generated permission table from TARGET_OUT before packing.
TARGET_RECOVERY_DEVICE_MODULES += fs_config_files_system

PRODUCT_PACKAGES += \
    qcom_decrypt \
    qcom_decrypt_fbe \
    resetprop \
    libion \
    libnativewindow \
    libui

TARGET_RECOVERY_DEVICE_MODULES += libion libnativewindow libui reno10x_recovery_graphics \
    android.hardware.common-V2-ndk \
    android.hardware.graphics.common-V6-ndk \
    android.hardware.graphics.allocator-V2-ndk \
    android.hardware.graphics.allocator@2.0
# Native libui/libgralloctypes/libnativewindow also need these providers in
# the ramdisk; building their transitive dependencies does not stage them.
RECOVERY_LIBRARY_SOURCE_FILES += \
    $(TARGET_OUT_SHARED_LIBRARIES)/libion.so \
    $(TARGET_OUT_SHARED_LIBRARIES)/libnativewindow.so \
    $(TARGET_OUT_SHARED_LIBRARIES)/libui.so \
    $(TARGET_OUT_SHARED_LIBRARIES)/android.hardware.common-V2-ndk.so \
    $(TARGET_OUT_SHARED_LIBRARIES)/android.hardware.graphics.common-V6-ndk.so \
    $(TARGET_OUT_SHARED_LIBRARIES)/android.hardware.graphics.allocator-V2-ndk.so \
    $(TARGET_OUT_SHARED_LIBRARIES)/android.hardware.graphics.allocator@2.0.so

PRODUCT_VENDOR_PROPERTIES += ro.hardware.egl=adreno ro.hardware.gralloc=msmnile
DEVICE_MANIFEST_FILE := $(LOCAL_PATH)/manifest.xml

# All copied init files are device-specific extensions to AERA's native init.
PRODUCT_COPY_FILES += \
    system/core/libprocessgroup/profiles/task_profiles.json:$(TARGET_COPY_OUT_RECOVERY)/root/system/etc/task_profiles.json \
    system/libhidl/vintfdata/manifest.xml:$(TARGET_COPY_OUT_RECOVERY)/root/system/etc/vintf/manifest.xml \
    system/hwservicemanager/hwservicemanager.xml:$(TARGET_COPY_OUT_RECOVERY)/root/system/etc/vintf/manifest/hwservicemanager.xml \
    $(LOCAL_PATH)/recovery/root/init.recovery.qcom.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.qcom.rc \
    $(LOCAL_PATH)/recovery/root/init.recovery.reno10x-crypto.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.reno10x-crypto.rc \
    $(LOCAL_PATH)/recovery/root/init.recovery.usb.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.usb.rc \
    $(LOCAL_PATH)/recovery/root/ueventd.qcom.rc:$(TARGET_COPY_OUT_RECOVERY)/root/ueventd.qcom.rc \
    $(LOCAL_PATH)/recovery/root/system/etc/twrp.flags:$(TARGET_COPY_OUT_RECOVERY)/root/system/etc/twrp.flags \
    $(LOCAL_PATH)/recovery/root/vendor/etc/init/aera-gralloc.rc:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/etc/init/aera-gralloc.rc \
    $(LOCAL_PATH)/manifest.xml:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/etc/vintf/manifest.xml

include $(LOCAL_PATH)/proprietary-files.mk
