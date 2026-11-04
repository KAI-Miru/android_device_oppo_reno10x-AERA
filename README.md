# AERA for OPPO Reno 10x Zoom

Experimental tree for the Reno 10x Zoom unit reporting project 18115. Derived from KAI-Miru's Guacamole AERA tree at 95f8b31086b15820ac6a45ee5131520968de3048.

Check out at device/oppo/reno10x, use the AERA projects in sources.lock.json, select twrp_reno10x-bp2a-eng, and build recoveryimage.

- Physical A-only, 64 MiB dedicated recovery, no super, A/B boot control, or fastbootd.
- Stock Reno boot v2 geometry, kernel, DTB and embedded DTBO. The gzip kernel round-trips to stock using the same compression format as the Reno image that booted. The build uses a 32 MiB legacy LZMA ramdisk.
- Reno ext4 userdata with ICE and wrapped keys. Keep additional fstab processing for the installed ROM. Metadata decryption remains unresolved.
- Start from the graphics configuration used in the booted Guacamole-derived test. See the blob manifest for provenance. Reno WLAN is disabled pending device-specific validation.

The source lock includes the Reno metadata upgrade experiment in Vold and Keystore2. Device validation of this experiment is pending. Before any test boot, check the image against the physical partition size and verify the recovery AVB hash footer.
