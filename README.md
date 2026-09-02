# kernel_xiaomi_begonia

Custom Linux 4.14.186 kernel for the **Redmi Note 8 Pro** (`begonia`,
MediaTek Helio G90T / MT6785).

## What this repository is

It is a **patch series plus CI**, not a fork. Upstream
[MiCode/Xiaomi_Kernel_OpenSource](https://github.com/MiCode/Xiaomi_Kernel_OpenSource)
branch `begonia-r-oss` is a *single-commit source drop* (`git rev-list --count
HEAD` = 1), so forking it would add ~200 MiB to this repo and give no usable
history. The workflow clones the pristine upstream tree and applies
`patches/` on top, which keeps every local change reviewable.

```
patches/   3 commits applied with `git am` onto upstream begonia-r-oss
AnyKernel3/  flashable-ZIP template with the begonia init tweaks
.github/workflows/build.yml  Proton-Clang build -> Image.gz-dtb -> ZIP
```

## What the patches do

**1. KernelSU-Next (legacy) + governor/network tuning**

* KernelSU-Next pinned to `v3.2.0-legacy`. Mainline (>= v3.3.0) does **not**
  compile on 4.14: `hook/syscall_hook.h` uses `syscall_fn_t`, introduced on
  arm64 only in 4.19.
* `kernel/sched/cpufreq_schedutil.c`: per-cluster rate limits hardcoded for
  begonia's 6x A55 + 2x A76 split — LITTLE up 500 us / down 2000 us,
  BIG up 250 us / down 4000 us.
* defconfig: schedutil as the default governor, BBR + fq as the default
  network stack, overlayfs, ext4 POSIX ACL/security.

**2. Manual KernelSU hooks instead of kprobes**

kprobes are disabled in every known working begonia configuration and are
reported to bootloop on 4.14 MTK arm64. Hooks are instead compiled into the
tree behind `#ifdef CONFIG_KSU`:

| file | function | hook |
|---|---|---|
| `fs/exec.c` | `do_execveat_common` | `ksu_handle_execveat_ksud`, `ksu_handle_execveat_sucompat` |
| `fs/open.c` | `sys_faccessat` | `ksu_handle_faccessat` |
| `fs/stat.c` | `vfs_statx` | `ksu_handle_stat` |
| `fs/read_write.c` | `vfs_read` | `ksu_handle_vfs_read` |
| `drivers/input/input.c` | `input_handle_event` | `ksu_handle_input_handle_event` |
| `kernel/reboot.c` | `sys_reboot` | `ksu_handle_sys_reboot` |

**3. MediaTek gen4m Wi-Fi built into the image**

`begonia-r-oss` ships **no Wi-Fi driver** —
`drivers/misc/mediatek/connectivity/Makefile` says "Do Nothing, move to
standalone repo". The driver lives in
[MiCode/MTK_kernel_modules](https://github.com/MiCode/MTK_kernel_modules)
branch `begonia-r-oss`, which CI clones *next to* the kernel checkout because
the Makefile resolves it as `$(srctree)/../vendor/mediatek/kernel_modules`.
Prebuilt vendor `.ko` files cannot be reused: their vermagic will not match a
self-built kernel. Three upstream defects had to be fixed:

* `ABS_PATH_TO_*` used a bare `$(srctree)/../...`, but under an `O=` build
  `srctree` is the relative string `..`, so every symlink pointed at a
  nonexistent `drivers/misc/vendor/...`. Now `$(abspath ...)`.
* `CONFIG_WLAN_DRV_BUILD_IN` was never a Kconfig symbol, only an environment
  variable, so it could not be expressed in a defconfig. Added.
* `-Werror` in 7 vendor Makefiles made legacy-C warnings fatal on any modern
  toolchain. Stripped in CI.

## SELinux

Left **enforcing**. No `androidboot.selinux=permissive` in the cmdline.

## Building

Push to `main`, or run the workflow manually and optionally override the
KernelSU-Next tag. Artifacts: the flashable AnyKernel3 ZIP, the raw
`Image.gz-dtb`, and the `.config` + build log.

Flashing replaces your boot image. Take a backup first.
