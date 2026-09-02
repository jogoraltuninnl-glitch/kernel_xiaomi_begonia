### AnyKernel3 Ramdisk Mod Script
## begonia (Redmi Note 8 Pro / MT6785 Helio G90T) - KernelSU-Next + tuned
## base template: osm0sis @ xda-developers

### AnyKernel setup
# global properties
properties() { '
kernel.string=begonia-ksun-tuned (4.14.186 + KernelSU-Next legacy) by Egor
do.devicecheck=1
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=begonia
device.name2=begoniain
device.name3=Redmi Note 8 Pro
device.name4=
device.name5=
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties

### AnyKernel install
## boot files attributes
boot_attributes() {
set_perm_recursive 0 0 755 644 $RAMDISK/*;
set_perm_recursive 0 0 750 750 $RAMDISK/init* $RAMDISK/sbin;
} # end attributes

# boot shell variables
BLOCK=/dev/block/bootdevice/by-name/boot;
IS_SLOT_DEVICE=0;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

# boot install
dump_boot;

# ---------------------------------------------------------------------------
# init.begonia_tweaks.rc injection
#
# Everything under AnyKernel3/ramdisk/ is merged into the unpacked ramdisk by
# dump_boot, so at this point $RAMDISK/init.begonia_tweaks.rc already exists.
# What is left is making init actually parse it.
#
# begonia's boot.img layout differs between MIUI (Android 10/11) and AOSP
# ROMs, so we probe instead of assuming:
#   1. classic ramdisk with a real /init.rc  -> add an "import" line
#   2. first-stage-only ramdisk (system-as-root) -> no /init.rc to patch;
#      fall back to Magisk's /overlay.d mechanism, which merges *.rc files
#      into init at boot.
# ---------------------------------------------------------------------------
ui_print " ";
ui_print "Installing init.begonia_tweaks.rc ...";

if [ -f $RAMDISK/init.begonia_tweaks.rc ]; then
  set_perm 0 0 750 $RAMDISK/init.begonia_tweaks.rc;

  if [ -f $RAMDISK/init.rc ]; then
    # --- case 1: legacy / full ramdisk -------------------------------------
    backup_file init.rc;
    # insert_line is idempotent: arg2 is the "already present?" probe, so
    # re-flashing the ZIP will never duplicate the import.
    # init.environ.rc is imported by every AOSP init.rc, so it is a stable
    # anchor; if it is missing we prepend patch/begonia_import instead.
    if grep -q "import /init.environ.rc" $RAMDISK/init.rc; then
      insert_line init.rc "import /init.begonia_tweaks.rc" after \
        "import /init.environ.rc" "import /init.begonia_tweaks.rc";
    else
      prepend_file init.rc "import /init.begonia_tweaks.rc" begonia_import;
    fi;
    ui_print "  - patched ramdisk init.rc (import added)";

  else
    # --- case 2: first-stage-only ramdisk (system-as-root) -----------------
    mkdir -p $RAMDISK/overlay.d;
    mv -f $RAMDISK/init.begonia_tweaks.rc $RAMDISK/overlay.d/init.begonia_tweaks.rc;
    set_perm 0 0 750 $RAMDISK/overlay.d/init.begonia_tweaks.rc;
    ui_print "  - no /init.rc in ramdisk (system-as-root)";
    ui_print "  - installed via /overlay.d instead";
  fi;
else
  ui_print "  ! init.begonia_tweaks.rc missing from the ZIP - skipped";
fi;

# ---------------------------------------------------------------------------
# Kernel cmdline: quiet the console. SELinux is deliberately left ENFORCING
# (KernelSU does not need permissive, and permissive breaks attestation).
# ---------------------------------------------------------------------------
patch_cmdline "loglevel" "loglevel=0";

write_boot;
## end boot install

ui_print " ";
ui_print "Done. Reboot and verify with:";
ui_print "  adb shell getprop begonia.tweaks.applied";
ui_print "  adb shell cat /sys/devices/system/cpu/cpufreq/policy6/schedutil/up_rate_limit_us";
