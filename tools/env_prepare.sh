# Environment Preparation For SimpleKernelInstaller
# By KeJia

# setup path
chmod +x $MODPATH/tools/*
export PATH="$MODPATH/tools:$PATH"
cd $MODPATH

# self check
if [ ! -e $MODPATH/*Image* ] && [ ! -e $MODPATH/*.dtb ] && [ ! -e $MODPATH/*dtbo*.img ]; then
    abort "! kernel/dtb/dtbo not found! This package may be broken!"
fi

# check data
DATA=false
mount /data 2>/dev/null
if grep ' /data ' /proc/mounts | grep -vq 'tmpfs'; then
    touch /data/.rw && rm /data/.rw && DATA=true
fi

# print_title (from magisk)
print_title() {
    local len line1len line2len bar
    line1len=$(echo -n $1 | wc -c)
    line2len=$(echo -n $2 | wc -c)
    len=$line2len
    [ $line1len -gt $line2len ] && len=$line1len
    len=$((len + 2))
    bar=$(printf "%${len}s" | tr ' ' '*')
    ui_print "$bar"
    ui_print " $1 "
    [ "$2" ] && ui_print " $2 "
    ui_print "$bar"
}

# Get Kernel Name
name=$(grep '^name=' $MODPATH/config.conf | cut -d '=' -f 2)

# devicename check (from anykernel3)
check_devicename() {
    local device devicename match product testname vendordevice vendorproduct;
    ui_print "- Checking devicename...";
    device=$(getprop ro.product.device 2>/dev/null);
    product=$(getprop ro.build.product 2>/dev/null);
    vendordevice=$(getprop ro.product.vendor.device 2>/dev/null);
    vendorproduct=$(getprop ro.vendor.product.device 2>/dev/null);
    for testname in $(grep '^devicename.*=' $MODPATH/config.conf | cut -d= -f2-); do
        for devicename in $device $product $vendordevice $vendorproduct; do
            if [ "$devicename" == "$testname" ]; then
                ui_print "- This device is '$testname'."
                    match=1
                    break 2
            fi
            ui_print "! This device is not '$testname'."
        done
    done
    if [ ! "$match" ]; then
        abort "! This device cannot use this kernel."
    fi
}

# Get boot partition name
if [ -e /dev/block/bootdevice/by-name/init_boot* ]; then
    export boot="/dev/block/bootdevice/by-name/init_boot$(getprop ro.boot.slot_suffix)"
elif [ ! -e /dev/block/bootdevice/by-name/boot* ]; then
    abort "! Unsupport Environment!"
elif test -z "$(getprop ro.boot.slot_suffix)"; then
    export boot="/dev/block/bootdevice/by-name/boot"
else
    export boot="/dev/block/bootdevice/by-name/boot$(getprop ro.boot.slot_suffix)"
fi

# Get dtbo partition name
if [ ! -e /dev/block/bootdevice/by-name/dtbo* ]; then
    export dtbo="null"
elif test -z "$(getprop ro.boot.slot_suffix)"; then
    export dtbo="/dev/block/bootdevice/by-name/dtbo"
else
    export dtbo="/dev/block/bootdevice/by-name/dtbo$(getprop ro.boot.slot_suffix)"
fi

install() {
    if [ -e $MODPATH/*Image* ] || [ -e $MODPATH/*.dtb ]; then
        ui_print "- Getting 'boot' Image..."
        dd if=$boot of=$MODPATH/boot.img
        ui_print "- Unpacking 'boot' Image..."
        magiskboot unpack $MODPATH/boot.img
        if [ -e $MODPATH/*Image*-dtb ]; then
            ui_print "- Replacing kernel and dtb..."
            magiskboot split $(find $MODPATH/ -type f -name "*Image*-dtb")
            REPLACEDDTB=true
        elif [ -e $MODPATH/Image ]; then
            ui_print "- Replacing kernel..."
            mv $MODPATH/Image kernel
        elif [ -e $MODPATH/*Image* ]; then
            ui_print "- Replacing kernel..."
            magiskboot decompress $(find $MODPATH/ -type f -name "*Image*") kernel
        fi
        if [ "$REPLACEDDTB" != "true"  ]; then
            ui_print "- Replacing dtb..."
            mv $MODPATH/*.dtb kernel_dtb
        fi
        ui_print "- Repacking 'boot' Image..."
        magiskboot repack $MODPATH/boot.img
        ui_print "- Flashing 'boot' Image..."
        dd if=$MODPATH/new-boot.img of=$boot
        if $DATA; then
            ui_print "- Backing up 'boot' Image..."
            rm /data/boot_backup*.img
            mv $MODPATH/boot.img "/data/boot_backup_$(date +'%Y%m%d_%H%M%S').img"
            ui_print "- You can find 'boot' backup in /data !"
        else
            ui_print "! /data is not writable! Skipping backup..."
        fi
    fi
    if [ -e $MODPATH/*dtbo*.img ] && [ $dtbo != "null" ]; then
        ui_print "- Flashing 'dtbo' Image..."
        dd if=$(find $MODPATH/ -type f -name "*dtbo*.img") of=$dtbo
    fi
        ui_print "- Install Success!"
}

clean_gpu_cache() {
    if $DATA; then
        ui_print "- Cleaning GPU cache..."
        find /data/user_de/*/*/*cache/* -iname "*shader*" -exec rm -rf {} +
        find /data/data/* -iname "*shader*" -exec rm -rf {} +
        find /data/data/* -iname "*graphitecache*" -exec rm -rf {} +
        find /data/data/* -iname "*gpucache*" -exec rm -rf {} +
        find /data_mirror/data*/*/*/*/* -iname "*shader*" -exec rm -rf {} +
        find /data_mirror/data*/*/*/*/* -iname "*graphitecache*" -exec rm -rf {} +
        find /data_mirror/data*/*/*/*/* -iname "*gpucache*" -exec rm -rf {} +
        ui_print "- GPU cache cleaning completed."
    else
        ui_print '! /data is not writable! Skipping GPU cache cleaning...'
    fi
}