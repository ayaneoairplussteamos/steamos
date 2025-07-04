#!/bin/bash

set -e

ACTION=$1
IMG_FILE=$2


src_path=/frzr_root/deployments
dst_path=/mnt/sk/deployments

function mount_image {
    if [ -z "$IMG_FILE" ]; then
        echo "Usage: $0 mount <img_file>"
        exit 1
    fi

    echo "Mounting image $IMG_FILE"
    # check qemu-nbd is installed
    if [ ! -x "$(command -v qemu-nbd)" ]; then
        echo "qemu-nbd is not installed. Please install it first."
        exit 1
    fi
    sudo modprobe nbd
    sudo qemu-nbd -c /dev/nbd0 "$IMG_FILE"

    sleep 2
    sudo fdisk -l /dev/nbd0

    sudo mkdir -p /mnt/sk
    sudo mount /dev/nbd0p2 /mnt/sk
    sudo mount /dev/nbd0p1 /mnt/sk/boot
}

function umount_image {
    echo "Unmounting image $IMG_FILE"
    sudo umount /mnt/sk/boot || true
    sudo umount /mnt/sk || true
    sudo qemu-nbd -d /dev/nbd0 || true
    sudo modprobe -r nbd || true
}

function send_to_vmdk {
    echo "sending to vmdk"

    cd $src_path
    release_name=$(frzr-release)
    echo "release_name: $release_name"
    # delete directory if name not release_name
    for d in "$src_path"/*; do
        if [[ -d "$d" && "$(basename "$d")" != "$release_name" ]]; then
            echo "删除旧版本 $d"
            # 交互式删除
            read -p "是否删除 $d? [y/n]" -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                sudo btrfs subvolume delete "$d"
            fi
        fi
    done

    echo "创建只读快照"
    subname=$(ls)
    sudo btrfs subvolume snapshot -r "$subname" "${subname}_r"

    echo "删除vmdk中的旧版本"
    cd "$dst_path"
    sudo btrfs subvolume delete chimeraos-4*_* || true
    sudo btrfs filesystem sync .

    echo "发送到vmdk"
    sudo btrfs send --proto 2 --compressed-data "${src_path}/${subname}_r" | sudo btrfs receive "${dst_path}"/.

    sudo mv "${subname}_r" "${subname}"
    sudo btrfs subvolume delete "${src_path}/${subname}_r"

}

function copy_kernel {
    echo "copy kernel"
    sudo rm -rf /mnt/sk/boot/chimeraos-*
    release_name=$(frzr-release)
    sudo cp -v /boot/vmlinuz-linux /mnt/sk/boot/vmlinuz-linux || true
    sudo cp -v /boot/initramfs-linux.img /mnt/sk/boot/initramfs-linux.img || true
    sudo cp -v /boot/amd-ucode.img /mnt/sk/boot/amd-ucode.img || true
    sudo cp -v /boot/intel-ucode.img /mnt/sk/boot/intel-ucode.img || true
    sudo cp -rv /frzr_root/boot/"${release_name}" /mnt/sk/boot/ || true

    sudo sed -i "s/chimeraos-[0-9a-zA-Z-]*_[0-9a-zA-Z-]*/${release_name}/g" /mnt/sk/boot/loader/entries/frzr.conf
}

function rsync_steam {
    echo "rsync steam"
    local srcpath="${HOME}/.local/share/Steam/"
    local dstpath="/mnt/sk/${HOME}/.local/share/Steam/"
    if [ ! -d "$srcpath" ]; then
        echo "Steam directory not found"
        exit 1
    fi
    if [ ! -d "$dstpath" ]; then
        echo "Destination directory not found"
        exit 1
    fi

    rm -rf "$srcpath/ubuntu12_32/steam-runtime*" || true
    rm -rf "$srcpath/ubuntu12_64/steam-runtime-sniper" || true

    clean_steam "$dstpath"

    sudo rsync -av --delete --progress \
        "$srcpath" "$dstpath" \
        --exclude 'friends' \
        --exclude 'config' \
        --exclude 'compatibilitytools.d' \
        --exclude 'steamapps' \
        --exclude 'userdata' \
        --exclude 'logs' \
        --exclude 'depotcache' \
        --exclude '.crash' \
        --exclude '*_log.txt' \
        --exclude 'appcache' \
        --exclude 'package/*.zip*' \
        --exclude 'steam-runtime' \
        --exclude 'steamrt' \
        --exclude 'steamrt64' \
        --exclude 'steam-runtime.old' \
        --exclude 'steam-runtime-sniper' 
        

    clean_steam "$dstpath"
}

function clean_steam {
    echo "clean steam"
    local clean_path=$1
    if [ -z "$clean_path" ]; then
        return
    fi
    
    rm -rf "$clean_path/ubuntu12_32/steam-runtime*" || true
    rm -rf "$clean_path/ubuntu12_64/steam-runtime-sniper" || true

    rm -rf "$clean_path/steamrt" || true
    rm -rf "$clean_path/steamrt64" || true

    rm -rf "$clean_path/appcache" || true
    rm -rf "$clean_path/friends" || true
    rm -rf "$clean_path/logs" || true
    rm -rf "$clean_path/compatibilitytools.d" || true
    rm -rf "$clean_path/steamapps" || true
}

function reset_home {
    echo "reset home"
    # delete all files in home
    destpath="/mnt/sk/home/${USER}"
    echo "destpath: $destpath"
    if [ -d "$destpath" ]; then
        sudo rm -rfv "$destpath/"*
        sudo rm -rfv "$destpath/".*
    fi
}

case $ACTION in
    mount)
        mount_image
        ;;
    umount)
        umount_image
        ;;
    send)
        send_to_vmdk
        ;;
    copy)
        copy_kernel
        ;;
    steam)
        rsync_steam
        ;;
    reset_home)
        reset_home
        ;;
    *)
        echo "Usage: $0 {mount|umount|send|copy|steam} <img_file>"
        exit 1
        ;;
esac