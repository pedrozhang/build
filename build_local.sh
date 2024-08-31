#!/bin/bash
# shellcheck disable=SC1083
# shellcheck disable=SC1091
# shellcheck disable=SC2001
# shellcheck disable=SC2010
# shellcheck disable=SC2012
# shellcheck disable=SC2027
# shellcheck disable=SC2045
# shellcheck disable=SC2046
# shellcheck disable=SC2086
# shellcheck disable=SC2103
# shellcheck disable=SC2115
# shellcheck disable=SC2162
# shellcheck disable=SC2164
# shellcheck disable=SC2181
# shellcheck disable=SC2185
GITHUB_WORKSPACE="$(
  cd "$(dirname "$0")" || exit
  pwd
)"
if [[ $1 == "--help" ]] || [[ $1 == "-help" ]] || [[ $1 == "help" ]]; then
  echo "sudo bash build_local_HyperOS.sh 待操作的系统包下载地址 机型代号小写 自定义版本号 VK内核 data是否加密 打包格式"
  exit
else
  URL="${1}"
fi
device="${2}"
date="${3}"
VK="${4}"
data="${5}"
pack_type="${6}"
echo 准备与链接有关的变量
if [[ "$device" == "umi" ]]; then
  ORIGIN_URL=https://hugeota.d.miui.com/OS1.0.5.0.TJBCNXM/miui_UMI_OS1.0.5.0.TJBCNXM_d01651ed86_13.0.zip
elif [[ "$device" == "cmi" ]]; then
  ORIGIN_URL=https://hugeota.d.miui.com/OS1.0.5.0.TJACNXM/miui_CMI_OS1.0.5.0.TJACNXM_64cdfa3fe5_13.0.zip
elif [[ "$device" == "cas" ]]; then
  ORIGIN_URL=https://hugeota.d.miui.com/OS1.0.4.0.TJJCNXM/miui_CAS_OS1.0.4.0.TJJCNXM_40f432b58e_13.0.zip
elif [[ "$device" == "apollo" ]]; then
  ORIGIN_URL=https://hugeota.d.miui.com/V14.0.5.0.SJDCNXM/miui_APOLLO_V14.0.5.0.SJDCNXM_e727f2446b_12.0.zip
elif [[ "$device" == "thyme" ]]; then
  ORIGIN_URL=https://hugeota.d.miui.com/OS1.0.4.0.TGACNXM/miui_THYME_OS1.0.4.0.TGACNXM_80dbab1cd4_13.0.zip
elif [[ "$device" == "alioth" ]]; then
  ORIGIN_URL=https://hugeota.d.miui.com/OS1.0.6.0.TKHCNXM/miui_ALIOTH_OS1.0.6.0.TKHCNXM_101dfdb5be_13.0.zip
fi
target_device=$(echo $URL | cut -d"_" -f2)
target_device=${target_device,,}
os_date=$(echo $URL | cut -d"/" -f4)
ZIP_NAME_TARGET=$(echo $URL | sed 's/.*\(miui_.*\.zip\).*/\1/')
echo 准备环境
sudo timedatectl set-timezone Asia/Shanghai
Device=${device^^}
host=$(uname -n)
bottom_os_date=$(echo $ORIGIN_URL | cut -d"/" -f4)
origin_bottom_date=$(echo $ORIGIN_URL | cut -d"/" -f4)
origin_bottom_date=${origin_bottom_date/OS1/V816}
ORIGIN_ZIP_NAME=$(echo $ORIGIN_URL | sed 's/.*\(miui_.*\.zip\).*/\1/')
origin_date=${os_date/OS1/V816}
date2=${date/OS1/V816}
if [[ "${device,,}" == "umi" ]] || [[ "${device,,}" == "cmi" ]] || [[ "${device,,}" == "cas" ]] || [[ "${device,,}" == "apollo" ]]; then
  bottom_soc=865
elif [[ "${device,,}" == "thyme" ]] || [[ "${device,,}" == "alioth" ]]; then
  bottom_soc=870
fi
APKEditor="java -jar "$GITHUB_WORKSPACE"/tools/jar/APKEditor.jar"
sudo apt-get install -y python3 aria2 p7zip-full unzip bc openjdk-19-jre-headless
sudo chmod -R 777 "$GITHUB_WORKSPACE"/tools
echo 解包
mkdir -p "$GITHUB_WORKSPACE"/"$device"/config
mkdir -p "$GITHUB_WORKSPACE"/images/config
mkdir -p "$GITHUB_WORKSPACE"/zip
7z x "$GITHUB_WORKSPACE"/"$ORIGIN_ZIP_NAME" -r -o"$GITHUB_WORKSPACE"/"$device"
for i in odm vendor; do
  echo "正在解压 $i"
  sudo "$GITHUB_WORKSPACE"/tools/binary/imgextractorLinux "$GITHUB_WORKSPACE"/"$device"/$i.img "$GITHUB_WORKSPACE"/"$device" >/dev/null
  echo "解压 $i 完成"
  rm -rf "$GITHUB_WORKSPACE"/"$device"/$i.img
done
mkdir -p "$GITHUB_WORKSPACE"/TARGET/config
7z x "$GITHUB_WORKSPACE"/"$ZIP_NAME_TARGET" -r -o"$GITHUB_WORKSPACE"/TARGET
if [[ "$(whoami)" == "runner" ]]; then
  rm -rf "$GITHUB_WORKSPACE"/"$ORIGIN_ZIP_NAME"
  rm -rf "$GITHUB_WORKSPACE"/"$ZIP_NAME_TARGET"
fi
for i in system product system_ext mi_ext; do
  "$GITHUB_WORKSPACE"/tools/binary/payload-dumper-go -o "$GITHUB_WORKSPACE"/images/ -p $i "$GITHUB_WORKSPACE"/TARGET/payload.bin >/dev/null
  echo "正在解压 $i"
  cd "$GITHUB_WORKSPACE"/images && "$GITHUB_WORKSPACE"/tools/binary/extract.erofs -i "$GITHUB_WORKSPACE"/images/$i.img -x >/dev/null && cd "$GITHUB_WORKSPACE"
  echo "解压 $i 完成"
  rm -rf "$GITHUB_WORKSPACE"/images/$i.img
done
rm -rf "$GITHUB_WORKSPACE"/TARGET
vendor_build_prop="$GITHUB_WORKSPACE"/"$device"/vendor/build.prop
odm_build_prop="$GITHUB_WORKSPACE"/"$device"/odm/etc/build.prop
system_build_prop="$GITHUB_WORKSPACE"/images/system/system/build.prop
system_dlkm_build_prop="$GITHUB_WORKSPACE"/images/system/system/system_dlkm/etc/build.prop
system_ext_build_prop="$GITHUB_WORKSPACE"/images/system_ext/etc/build.prop
product_build_prop="$GITHUB_WORKSPACE"/images/product/etc/build.prop
mi_ext_build_prop="$GITHUB_WORKSPACE"/images/mi_ext/etc/build.prop
echo 输出包体信息
bottom_security_patch=$(grep "ro.vendor.build.security_patch=" "$vendor_build_prop" | awk -F "=" '{print $2}')  # 底包的 Android 安全更新版本, 例: 2024-07-01
bottom_base_line=$(grep "ro.vendor.build.id=" "$vendor_build_prop" | awk -F "=" '{print $2}')                   # 底包的 Android 基线版本, 例: TKQ1.221114.001
target_security_patch=$(grep "ro.build.version.security_patch=" "$system_build_prop" | awk -F "=" '{print $2}') # 移植包的 Android 安全更新版本, 例: 2024-0-017
target_base_line=$(grep "ro.system.build.id=" "$system_build_prop" | awk -F "=" '{print $2}')                   # 移植包的 Android 基线版本, 例: UKQ1.230804.001
echo "底包的 OS 版本: $bottom_os_date"
echo "底包的 Android 安全更新版本: $bottom_security_patch"
echo "底包的 Android 基线版本: $bottom_base_line"
echo "移植包的 OS 版本: $os_date"
echo "移植包的 Android 安全更新版本: $target_security_patch"
echo "移植包的 Android 基线版本: $target_base_line"
echo 替换相关文件
# 修改vendor请在该部分修改，路径为"$GITHUB_WORKSPACE"/"$device"/vendor
info_necessary() {
  echo -e "\e[1;31m$1\e[0m"
}
info_optional() {
  echo -e "\e[1;33m$1\e[0m"
}
info_functional() {
  echo -e "\e[1;34m$1\e[0m"
}
Find_character() {
  FIND_FILE="$1"
  FIND_STR="$2"
  if [ $(sudo grep -c "$FIND_STR" $FIND_FILE) -ne '0' ]; then
    Character_present=true
    echo "找到指定字符: $2"
  else
    Character_present=false
    echo "未找到指定字符: $2"
  fi
}
# 修改apk By PedroZ
info_functional 修改apk
source "$GITHUB_WORKSPACE"/common_files/mod.sh

# 分区表源文件替换 By zjw2017
info_necessary 分区表源文件替换
if [[ "$bottom_soc" == "865" ]]; then
  mv "$GITHUB_WORKSPACE"/common_files/fstab.qcom.865 "$GITHUB_WORKSPACE"/common_files/fstab.qcom
elif [[ "$bottom_soc" == "870" ]]; then
  mv "$GITHUB_WORKSPACE"/common_files/fstab.qcom.870 "$GITHUB_WORKSPACE"/common_files/fstab.qcom
fi
# 去除强制加密 By Meetingfate
if [[ "$data" == "true" ]]; then
  info_functional 去除强制加密
  sudo sed -i 's/fileencryption//g' "$GITHUB_WORKSPACE"/common_files/fstab.qcom
fi
# 去除AVB2.0校验 By Meetingfate
info_necessary 去除AVB2.0校验
"$GITHUB_WORKSPACE"/tools/binary/vbmeta-disable-verification "$GITHUB_WORKSPACE"/"$device"/firmware-update/vbmeta.img
"$GITHUB_WORKSPACE"/tools/binary/vbmeta-disable-verification "$GITHUB_WORKSPACE"/"$device"/firmware-update/vbmeta_system.img
# 修补 TWRP By zjw2017
info_necessary "修补 TWRP"
mkdir -p "$GITHUB_WORKSPACE"/twrp_patch/boot
mkdir -p "$GITHUB_WORKSPACE"/twrp_patch/twrp
twrp_zip_name="$(ls "$GITHUB_WORKSPACE"/"$device"_files | grep skkk)"
echo "TWRP压缩包名为：$twrp_zip_name"
unzip -o -q "$GITHUB_WORKSPACE"/"$device"_files/$twrp_zip_name -d "$GITHUB_WORKSPACE"/twrp_patch/twrp
twrp_img_name=$(ls "$GITHUB_WORKSPACE"/twrp_patch/twrp)
echo "TWRP镜像名为：$twrp_img_name"
if [[ "$bottom_soc" == "865" ]]; then
  rm -rf "$GITHUB_WORKSPACE"/"$device"/firmware-update/recovery.img
  mv "$GITHUB_WORKSPACE"/twrp_patch/twrp/$twrp_img_name "$GITHUB_WORKSPACE"/"$device"/firmware-update/recovery.img
elif [[ "$bottom_soc" == "870" ]]; then
  cp -f "$GITHUB_WORKSPACE"/tools/binary/magiskboot "$GITHUB_WORKSPACE"/twrp_patch
  mv "$GITHUB_WORKSPACE"/twrp_patch/twrp/$twrp_img_name "$GITHUB_WORKSPACE"/twrp_patch/twrp/twrp.img
  mv -f "$GITHUB_WORKSPACE"/"$device"/firmware-update/boot.img "$GITHUB_WORKSPACE"/twrp_patch/boot
  cd "$GITHUB_WORKSPACE"/twrp_patch/twrp
  "$GITHUB_WORKSPACE"/twrp_patch/magiskboot unpack twrp.img
  cd "$GITHUB_WORKSPACE"/twrp_patch/boot
  "$GITHUB_WORKSPACE"/twrp_patch/magiskboot unpack boot.img
  cp "$GITHUB_WORKSPACE"/twrp_patch/twrp/ramdisk* "$GITHUB_WORKSPACE"/twrp_patch/boot
  "$GITHUB_WORKSPACE"/twrp_patch/magiskboot repack "$GITHUB_WORKSPACE"/twrp_patch/boot/boot.img "$GITHUB_WORKSPACE"/"$device"/firmware-update/boot.img
fi
rm -rf "$GITHUB_WORKSPACE"/twrp_patch
cd "$GITHUB_WORKSPACE"
# 修补boot By TheVoyager0777
info_necessary 修补boot
mkdir -p "$GITHUB_WORKSPACE"/boot
# boot文件准备 By zjw2017
if [[ "$device" == "umi" ]] || [[ "$device" == "cmi" ]]; then
  kernel_name="$(find "$GITHUB_WORKSPACE"/tools/kernel -maxdepth 1 -type f -name "*UCMI*")"
else
  kernel_name="$(find "$GITHUB_WORKSPACE"/tools/kernel -maxdepth 1 -type f -name "*${device^^}*")"
fi
if [ -n "$kernel_name" ]; then
  target_dir="$GITHUB_WORKSPACE"/tools/kernel/boot_${device}
  unzip -o -q "$kernel_name" kernels/miui/Image -d "$target_dir"
  mv "$target_dir"/kernels/miui/Image "$target_dir"
  rm -rf "$target_dir"/kernels
  rm -rf "$kernel_name"
fi
cd "$GITHUB_WORKSPACE"/boot
if [[ "$bottom_soc" == "865" ]]; then
  mv -f "$GITHUB_WORKSPACE"/"$device"/boot.img "$GITHUB_WORKSPACE"/boot
elif [[ "$bottom_soc" == "870" ]]; then
  mv -f "$GITHUB_WORKSPACE"/"$device"/firmware-update/boot.img "$GITHUB_WORKSPACE"/boot
fi
cp -f "$GITHUB_WORKSPACE"/tools/binary/magiskboot "$GITHUB_WORKSPACE"/boot
"$GITHUB_WORKSPACE"/boot/magiskboot unpack "$GITHUB_WORKSPACE"/boot/boot.img
if [[ "$bottom_soc" == "865" ]]; then
  "$GITHUB_WORKSPACE"/boot/magiskboot cpio "$GITHUB_WORKSPACE"/boot/ramdisk.cpio "add 0644 fstab.qcom "$GITHUB_WORKSPACE"/common_files/fstab.qcom"
fi
# 替换/vendor/etc/fstab.qcom By zjw2017
info_necessary 替换/vendor/etc/fstab.qcom
sudo cp -f "$GITHUB_WORKSPACE"/common_files/fstab.qcom "$GITHUB_WORKSPACE"/"$device"/vendor/etc
cd "$GITHUB_WORKSPACE"/boot
if [[ "$VK" == "true" ]]; then
  rm "$GITHUB_WORKSPACE"/boot/kernel
  mv "$GITHUB_WORKSPACE"/tools/kernel/boot_"$device"/Image "$GITHUB_WORKSPACE"/boot/kernel
fi
"$GITHUB_WORKSPACE"/boot/magiskboot repack "$GITHUB_WORKSPACE"/boot/boot.img "$GITHUB_WORKSPACE"/images/boot.img
rm -rf "$GITHUB_WORKSPACE"/boot
cd "$GITHUB_WORKSPACE"
if [[ "$bottom_soc" == "870" ]]; then
  # 修补vendor_boot
  info_necessary 修补vendor_boot
  mkdir -p "$GITHUB_WORKSPACE"/vendor_boot
  cd "$GITHUB_WORKSPACE"/vendor_boot
  mv -f "$GITHUB_WORKSPACE"/"$device"/firmware-update/vendor_boot.img "$GITHUB_WORKSPACE"/vendor_boot
  cp -f "$GITHUB_WORKSPACE"/tools/binary/magiskboot "$GITHUB_WORKSPACE"/vendor_boot
  "$GITHUB_WORKSPACE"/vendor_boot/magiskboot unpack -h "$GITHUB_WORKSPACE"/vendor_boot/vendor_boot.img
  comp=$("$GITHUB_WORKSPACE"/vendor_boot/magiskboot decompress ramdisk.cpio 2>&1 | grep -v 'raw' | sed -n 's;.*\[\(.*\)\];\1;p')
  if [ "$comp" ]; then
    mv -f ramdisk.cpio ramdisk.cpio.$comp
    "$GITHUB_WORKSPACE"/vendor_boot/magiskboot decompress ramdisk.cpio.$comp ramdisk.cpio
    if [ $? != 0 ] && $comp --help 2>/dev/null; then
      $comp -dc ramdisk.cpio.$comp >ramdisk.cpio
    fi
  fi
  mkdir -p ramdisk
  chmod 755 ramdisk
  cd ramdisk
  EXTRACT_UNSAFE_SYMLINKS=1 cpio -d -F ../ramdisk.cpio -i
  sudo cp -f "$GITHUB_WORKSPACE"/common_files/fstab.qcom "$GITHUB_WORKSPACE"/vendor_boot/ramdisk/first_stage_ramdisk/fstab.qcom
  sudo chmod 644 "$GITHUB_WORKSPACE"/vendor_boot/ramdisk/first_stage_ramdisk/fstab.qcom
  cd "$GITHUB_WORKSPACE"/vendor_boot/ramdisk
  find | sed 1d | cpio -H newc -R 0:0 -o -F ../ramdisk_new.cpio
  cd ..
  if [ "$comp" ]; then
    "$GITHUB_WORKSPACE"/vendor_boot/magiskboot compress=$comp ramdisk_new.cpio
    if [ $? != 0 ] && $comp --help 2>/dev/null; then
      $comp -9c ramdisk_new.cpio >ramdisk.cpio.$comp
    fi
  fi
  ramdisk=$(ls ramdisk_new.cpio* 2>/dev/null | tail -n1)
  if [ "$ramdisk" ]; then
    cp -f $ramdisk ramdisk.cpio
    case $comp in
    cpio)
      nocompflag="-n"
      ;;
    esac
    "$GITHUB_WORKSPACE"/vendor_boot/magiskboot repack $nocompflag "$GITHUB_WORKSPACE"/vendor_boot/vendor_boot.img "$GITHUB_WORKSPACE"/"$device"/firmware-update/vendor_boot.img
  fi
  sudo rm -rf "$GITHUB_WORKSPACE"/vendor_boot
  cd "$GITHUB_WORKSPACE"
fi
# 替换Overlay By Weverses
info_necessary 替换Overlay
if [[ "$device" != "alioth" ]] && [[ "$device" != "apollo" ]]; then
  mv "$GITHUB_WORKSPACE"/common_files/overlay_A14_patch.zip "$GITHUB_WORKSPACE"/common_files/overlay_A14_patch_"$device".zip
fi
sudo unzip -o -q "$GITHUB_WORKSPACE"/common_files/overlay_A14_patch_"$device".zip -d "$GITHUB_WORKSPACE"/images/product/overlay
# 通信共享
info_necessary 添加通信共享
repack=true
mkdir -p "$GITHUB_WORKSPACE"/mod/MiuiFrameworkResOverlay
sudo mv "$GITHUB_WORKSPACE"/images/product/overlay/MiuiFrameworkResOverlay.apk "$GITHUB_WORKSPACE"/mod
$APKEditor d -f -i "$GITHUB_WORKSPACE"/mod/MiuiFrameworkResOverlay.apk -o "$GITHUB_WORKSPACE"/mod/MiuiFrameworkResOverlay 2>&1 1>&/dev/null
Find_character "$GITHUB_WORKSPACE"/mod/MiuiFrameworkResOverlay/resources/package_1/res/values/bools.xml config_celluar_shared_support
if [[ $Character_present == true ]]; then
  value=$(grep "<bool name=\"config_celluar_shared_support\">" "$GITHUB_WORKSPACE"/mod/MiuiFrameworkResOverlay/resources/package_1/res/values/bools.xml | sed -n 's/.*<bool name="config_celluar_shared_support">\([^<]*\)<\/bool>.*/\1/p')
  if [[ "$value" != "true" ]]; then
    sed -i 's/<bool name="config_celluar_shared_support">.*<\/bool>/<bool name="config_celluar_shared_support">true<\/bool>/' "$GITHUB_WORKSPACE"/mod/MiuiFrameworkResOverlay/resources/package_1/res/values/bools.xml
  else
    repack=false
    sudo mv "$GITHUB_WORKSPACE"/mod/MiuiFrameworkResOverlay.apk "$GITHUB_WORKSPACE"/images/product/overlay
  fi
else
  last_record=$(awk '/<\/resources>/ {print substr(prev, index(prev, "\"") + 1, index(prev, "\">") - index(prev, "\"") - 1)} {prev = $0}' "$GITHUB_WORKSPACE"/mod/MiuiFrameworkResOverlay/resources/package_1/res/values/bools.xml)
  last_hex=$(grep -Eo 'id="0x[0-9a-fA-F]*" type="bool" name="'$last_record'"' "$GITHUB_WORKSPACE"/mod/MiuiFrameworkResOverlay/resources/package_1/res/values/public.xml | awk -F'id="' '{print $2}' | awk -F'"' '{print $1}')
  new_hex=$(printf "0x%x" $((last_hex + 1)))
  sed -i '/<\/resources>/i \ \ <bool name="config_celluar_shared_support">true<\/bool>' "$GITHUB_WORKSPACE"/mod/MiuiFrameworkResOverlay/resources/package_1/res/values/bools.xml
  sed -i "/name=\"$last_record\"/a \  <public id=\"$new_hex\" type=\"bool\" name=\"config_celluar_shared_support\" />" "$GITHUB_WORKSPACE"/mod/MiuiFrameworkResOverlay/resources/package_1/res/values/public.xml
fi
if [[ $repack == true ]]; then
  $APKEditor b -f -i "$GITHUB_WORKSPACE"/mod/MiuiFrameworkResOverlay -o "$GITHUB_WORKSPACE"/mod/MiuiFrameworkResOverlay_modified.apk 2>&1 1>&/dev/null
  sudo mv "$GITHUB_WORKSPACE"/mod/MiuiFrameworkResOverlay_modified.apk "$GITHUB_WORKSPACE"/images/product/overlay/MiuiFrameworkResOverlay.apk
fi
sudo rm -rf "$GITHUB_WORKSPACE"/mod
# 修复不开机 By Weverses
info_necessary 修复不开机
sudo sed -i "/persist.sys.millet.cgroup1=true/d" "$vendor_build_prop"
# 人脸修复 By Meetingfate
if [[ "$target_device" == "ishtar" ]] || [[ "$target_device" == "houji" ]] || [[ "$target_device" == "shennong" ]] || [[ "$target_device" == "aurora" ]]; then
  info_necessary 人脸修复
  sudo unzip -o "$GITHUB_WORKSPACE"/common_files/face.zip -d "$GITHUB_WORKSPACE"/images/product/app/MiuiBiometric3389
fi
# A14底层适配
if [[ "$target_device" == "houji" ]] || [[ "$target_device" == "shennong" ]] || [[ "$target_device" == "aurora" ]]; then
  # apex修复 By MeetingFate
  info_necessary apex修复
  sudo unzip -o -q "$GITHUB_WORKSPACE"/common_files/apex.zip -d "$GITHUB_WORKSPACE"/images/system_ext/apex
  # 修复开机内部错误 By MeetingFate
  info_necessary 修复开机内部错误
  sudo cp -f "$GITHUB_WORKSPACE"/common_files/manifest.xml "$GITHUB_WORKSPACE"/images/system_ext/etc/vintf
  # cust挂载修复 By MeetingFate
  info_necessary cust挂载修复
  sudo sed -i -e 's/^\(ro\.miui\.cust_erofs\)/# \1/' \
    -e 's/^\(ro\.miui\.preinstall_to_data\)/# \1/' \
    -e 's/^\(ro\.miui\.cust_img_path\)/# \1/' \
    -e 's/^\(ro\.miui\.product_to_cust\)/# \1/' \
    -e 's/^\(ro\.miui\.cust_erofs\)/# \1/' "$product_build_prop"
fi
# 修复认证信息 By MeetingFate
info_necessary 修复认证信息
sudo unzip -o -q "$GITHUB_WORKSPACE"/"$device"_files/overlay_"$device".zip -d "$GITHUB_WORKSPACE"/images/product/overlay
# 开机动画修复 By PedroZ
info_necessary 开机动画修复
if [[ $device =~ ^(alioth|apollo)$ ]]; then
  sudo cp -f "$GITHUB_WORKSPACE"/common_files/bootanimation_Redmi.zip -d "$GITHUB_WORKSPACE"/images/product/media/bootanimation.zip
else
  sudo cp -f "$GITHUB_WORKSPACE"/common_files/bootanimation.zip -d "$GITHUB_WORKSPACE"/images/product/media/bootanimation.zip
fi
# 删除重复的IFAAService/SoterService服务 By Meetingfate
info_necessary 删除重复的IFAAService/SoterService服务
for files in IFAAService SoterService; do
  appsui=$(sudo find "$GITHUB_WORKSPACE"/images/product/ -type d -iname "*${files}*")
  if [[ -n "$appsui" ]]; then
    echo "找到文件: $appsui"
    sudo rm -rf "$appsui"
  fi
done
# 分辨率修改 By Meetingfate
info_necessary 分辨率修复
Find_character "$product_build_prop" persist.miui.density_v2
if [[ $Character_present == true ]]; then
  sudo sed -i 's/persist.miui.density_v2=[^*]*/persist.miui.density_v2=440/' "$product_build_prop"
else
  sudo sed -i ''"$(sudo sed -n '/ro.miui.notch/=' "$product_build_prop")"'a persist.miui.density_v2=440' "$product_build_prop"
fi
Find_character "$product_build_prop" ro.sf.lcd_density
if [[ $Character_present == true ]]; then
  sudo sed -i 's/ro.sf.lcd_density=[^*]*/ro.sf.lcd_density=440/' "$product_build_prop"
else
  sudo sed -i ''"$(sudo sed -n '/persist.miui.density_v2/=' "$product_build_prop")"'i ro.sf.lcd_density=440' "$product_build_prop"
fi
# 修复自带相机 (来自10S的相机4.5) By PedroZ
info_necessary 修复自带相机
if [[ $device == "umi" || $device == "cmi" || $device == "thyme" ]]; then
  cat "$GITHUB_WORKSPACE"/common_files/Camera_leica.zip* >"$GITHUB_WORKSPACE"/common_files/Camera_leica.zip
  sudo unzip -o -q "$GITHUB_WORKSPACE"/common_files/Camera_leica.zip -d "$GITHUB_WORKSPACE"/images
  if [[ "$target_device" == "munch" ]]; then
    sudo sed -i '/<privapp-permissions package="com.android.camera">/a \ \ \ \ \ \ <permission name="android.permission.TURN_SCREEN_ON" \/>' "$GITHUB_WORKSPACE"/images/product/etc/permissions/privapp-permissions-product.xml
  fi
elif [[ $device == "apollo" ]]; then
  sudo unzip -o -q "$GITHUB_WORKSPACE"/common_files/Camera_apollo.zip -d "$GITHUB_WORKSPACE"/images
else
  sudo unzip -o -q "$GITHUB_WORKSPACE"/common_files/Camera.zip -d "$GITHUB_WORKSPACE"/images
fi
# NFC读写勿扰 By Weverses
info_optional NFC读写勿扰
Find_character "$vendor_build_prop" ro.vendor.nfc.dispatch_optim
if [[ $Character_present == true ]]; then
  sudo sed -i 's/ro.vendor.nfc.dispatch_optim=[^*]*/ro.vendor.nfc.dispatch_optim=2/' "$vendor_build_prop"
else
  sudo sed -i ''"$(sudo sed -n '/ro.vendor.nfc.repair/=' "$vendor_build_prop")"'a ro.vendor.nfc.dispatch_optim=2' "$vendor_build_prop"
fi
# 修复NFC By Weverses
info_necessary 修复NFC
NFC_Version=2
if [[ $device == "apollo" ]] || [[ "$NFC_Version" == "1" ]]; then
  for nfc_files in $(sudo find "$GITHUB_WORKSPACE"/images/product/pangu/system/ -iname "*nfc*"); do
    if [[ -n "$nfc_files" ]]; then
      echo "找到文件: $nfc_files"
      sudo rm -rf "$nfc_files"
    fi
  done
  sudo unzip -o -q "$GITHUB_WORKSPACE"/common_files/NFC.zip -d "$GITHUB_WORKSPACE"/images
else
  # 修复 NFC (Android14-v2.0) By Weverses
  for nfc_files in $(sudo find "$GITHUB_WORKSPACE"/images/product/pangu/system/ -iname "*nfc*"); do
    if [[ -n "$nfc_files" ]]; then
      echo "找到文件: $nfc_files"
      sudo rm -rf "$nfc_files"
    fi
  done
  sudo unzip -o -q "$GITHUB_WORKSPACE"/common_files/NFC_A14-app.zip -d "$GITHUB_WORKSPACE"/images
  #sudo unzip -o -q "$GITHUB_WORKSPACE"/common_files/NFC_A14-v2.0.zip -d "$GITHUB_WORKSPACE"/"$device"
  #sudo unzip -o -q "$GITHUB_WORKSPACE"/common_files/NFC_A14_config.zip -d "$GITHUB_WORKSPACE"/"$device"/vendor/etc
  sudo unzip -o -q "$GITHUB_WORKSPACE"/common_files/NFC-v2.1.zip -d "$GITHUB_WORKSPACE"/"$device"/vendor
  sudo rm -rf "$GITHUB_WORKSPACE"/"$device"/vendor/lib/vendor.nxp.hardware.nfc@1.0.so
  sudo rm -rf "$GITHUB_WORKSPACE"/"$device"/vendor/lib64/vendor.nxp.hardware.nfc@1.0.so
  sudo rm -rf "$GITHUB_WORKSPACE"/"$device"/vendor/lib/vendor.nxp.hardware.nfc@1.1.so
  sudo rm -rf "$GITHUB_WORKSPACE"/"$device"/vendor/lib64/vendor.nxp.hardware.nfc@1.1.so
  # 添加 Mi Beam
  info_functional "添加 Mi Beam"
  sudo cp -rf "$GITHUB_WORKSPACE"/common_files/android.hardware.nfc.beam.xml "$GITHUB_WORKSPACE"/images/system/system/etc/permissions
  sudo sed -i ''"$(sudo sed -n '/ro.vendor.nfc.dispatch_optim/=' "$vendor_build_prop")"'a ro.vendor.nfc.mibeam=1' "$vendor_build_prop"
  # NFC 2.0界面
  info_functional "NFC 2.0界面"
  sudo sed -i ''"$(sudo sed -n '/ro.vendor.nfc.mibeam/=' "$vendor_build_prop")"'a ro.vendor.nfc.wallet_fusion=1' "$vendor_build_prop"
  # 允许NFC读卡提醒
  info_functional "允许NFC读卡提醒"
  sudo sed -i ''"$(sudo sed -n '/ro.vendor.nfc.wallet_fusion/=' "$vendor_build_prop")"'a ro.vendor.nfc.secure_display_optim=1' "$vendor_build_prop"
fi
# 自动亮度修复 By Meetingfate
info_necessary 自动亮度修复
sudo unzip -o -q "$GITHUB_WORKSPACE"/"$device"_files/displayconfig.zip -d "$GITHUB_WORKSPACE"/images/product/etc/displayconfig
# 添加机型文件 By Weverses
info_necessary 添加机型文件
sudo rm -rf "$GITHUB_WORKSPACE"/images/product/etc/device_features/*
sudo cp -f "$GITHUB_WORKSPACE"/"$device"_files/"$device".xml "$GITHUB_WORKSPACE"/images/product/etc/device_features
if [[ "$device" == "alioth" ]]; then
  sudo cp -f "$GITHUB_WORKSPACE"/"$device"_files/aliothin.xml "$GITHUB_WORKSPACE"/images/product/etc/device_features
fi
# LHDC 修复 By MeetingFate
info_necessary 修复LHDC
"$GITHUB_WORKSPACE"/tools/binary/magiskboot hexpatch "$GITHUB_WORKSPACE"/images/system_ext/lib64/libbluetooth_qti.so 726F2E70726F647563742E646576696365 726F2E62742E6675636B2E646576696365
sudo sed -i ''"$(sudo sed -n '/ro.miui.has_gmscore/=' "$product_build_prop")"'a ro.bt.fuck.device=munch' "$product_build_prop"
if [[ "$bottom_soc" == "865" ]]; then
  # 声音动效动画 By PedroZ
  info_optional 声音动效动画
  sudo unzip -o -q "$GITHUB_WORKSPACE"/common_files/etc.zip -d "$GITHUB_WORKSPACE"/images/system/system/etc/audio
fi
# 修复扬声器校准 By PedroZ & zjw2017
info_necessary 修复扬声器校准
sudo unzip -o -q "$GITHUB_WORKSPACE"/common_files/spkcal.zip -d "$GITHUB_WORKSPACE"/images/system_ext/bin
echo "/system_ext/bin/spkcal_alioth u:object_r:system_file:s0" | sudo tee -a "$GITHUB_WORKSPACE"/images/config/system_ext_file_contexts
echo "/system_ext/bin/spkcal_cas u:object_r:system_file:s0" | sudo tee -a "$GITHUB_WORKSPACE"/images/config/system_ext_file_contexts
echo "/system_ext/bin/spkcal_cmi u:object_r:system_file:s0" | sudo tee -a "$GITHUB_WORKSPACE"/images/config/system_ext_file_contexts
echo "/system_ext/bin/spkcal_thyme u:object_r:system_file:s0" | sudo tee -a "$GITHUB_WORKSPACE"/images/config/system_ext_file_contexts
echo "/system_ext/bin/spkcal_umi u:object_r:system_file:s0" | sudo tee -a "$GITHUB_WORKSPACE"/images/config/system_ext_file_contexts
echo "/system_ext/bin/spkcal_venus u:object_r:system_file:s0" | sudo tee -a "$GITHUB_WORKSPACE"/images/config/system_ext_file_contexts
echo "system_ext/bin/spkcal_alioth 0 2000 0755" | sudo tee -a "$GITHUB_WORKSPACE"/images/config/system_ext_fs_config
echo "system_ext/bin/spkcal_cas 0 2000 0755" | sudo tee -a "$GITHUB_WORKSPACE"/images/config/system_ext_fs_config
echo "system_ext/bin/spkcal_cmi 0 2000 0755" | sudo tee -a "$GITHUB_WORKSPACE"/images/config/system_ext_fs_config
echo "system_ext/bin/spkcal_thyme 0 2000 0755" | sudo tee -a "$GITHUB_WORKSPACE"/images/config/system_ext_fs_config
echo "system_ext/bin/spkcal_umi 0 2000 0755" | sudo tee -a "$GITHUB_WORKSPACE"/images/config/system_ext_fs_config
echo "system_ext/bin/spkcal_venus 0 2000 0755" | sudo tee -a "$GITHUB_WORKSPACE"/images/config/system_ext_fs_config
# 恢复设置指纹预览图 By PedroZ
info_optional 恢复设置指纹预览图
sudo rm -rf "$GITHUB_WORKSPACE"/images/product/overlay/SettingsRroDeviceSystemUiOverlay.apk
# 极暗模式 By PedroZ
info_optional 极暗模式
cp -f "$GITHUB_WORKSPACE"/common_files/ExtraDimIconOverlay.apk "$GITHUB_WORKSPACE"/images/product/overlay
# 去广告 By MeetingFate
info_functional 去广告
sudo rm -rf "$GITHUB_WORKSPACE"/images/product/app/AnalyticsCore/*
sudo cp -f "$GITHUB_WORKSPACE"/common_files/AnalyticsCore.apk "$GITHUB_WORKSPACE"/images/product/app/AnalyticsCore
sudo rm -rf "$GITHUB_WORKSPACE"/images/product/app/MSA/*
sudo cp -f "$GITHUB_WORKSPACE"/common_files/MSA.apk "$GITHUB_WORKSPACE"/images/product/app/MSA
# 移除系统更新 By zjw2017
info_functional 移除系统更新
sudo rm -rf "$GITHUB_WORKSPACE"/images/product/app/Updater
# 移除推广 By PedroZ
info_functional 移除推广
for files in MIUIVipAccount MIUIMusicT MIUIYoupin NewHomeMIUI15 SmartHome MIUIVideo MIUIDuokanReader MiShop MIUIGameCenter; do
  data_app=$(find "$GITHUB_WORKSPACE"/images/product/data-app/ -name $files)
  sudo rm -rf "$data_app"
done
# 替换在线字幕的小爱翻译 By PedroZ
info_functional 替换在线字幕的小爱翻译
for Aiasst in $(sudo find "$GITHUB_WORKSPACE"/images/product/ -type d -iname "*aiasstvision*"); do
  if [[ -n "$Aiasst" ]]; then
    echo "找到文件: $Aiasst"
    sudo rm -rf "$Aiasst"
  fi
done
sudo mkdir -p "$GITHUB_WORKSPACE"/images/product/app/AiAsstVision
sudo unzip -o -q "$GITHUB_WORKSPACE"/common_files/AiAsstVision.zip -d "$GITHUB_WORKSPACE"/images/product/app/AiAsstVision
# 自定义刷新率 By PedroZ
info_functional 自定义刷新率
if [[ "$device" == "umi" ]] || [[ "$device" == "cmi" ]] || [[ "$device" == "thyme" ]]; then
  sudo sed -i 's/ro.vendor.display.default_fps=[^*]*/ro.vendor.display.default_fps=90/' "$vendor_build_prop"
elif [[ "$device" == "cas" ]] || [[ "$device" == "alioth" ]]; then
  sudo sed -i 's/ro.vendor.display.default_fps=[^*]*/ro.vendor.display.default_fps=120/' "$vendor_build_prop"
elif [[ "$device" == "apollo" ]]; then
  sudo sed -i 's/ro.vendor.display.default_fps=[^*]*/ro.vendor.display.default_fps=144/' "$vendor_build_prop"
fi
# 调整surface_flinger By PedroZ
info_necessary 调整surface_flinger
cat <<EOF | sudo tee -a "$vendor_build_prop" >/dev/null
ro.surface_flinger.enable_frame_rate_override=false
EOF
if [[ "$target_device" == "munch" ]]; then
  # 开启高级材质 By PedroZ
  info_necessary 开启高级材质
  cat <<EOF | sudo tee -a "$product_build_prop" >/dev/null
persist.sys.background_blur_supported=true
persist.sys.background_blur_status_default=true
persist.sys.background_blur_mode=2
EOF
fi
# 移除系统app签名校验 By MeetingFate
info_necessary 移除系统app签名校验
mkdir -p "$GITHUB_WORKSPACE"/corepatch/services
sudo mv -f "$GITHUB_WORKSPACE"/images/system/system/framework/services.jar "$GITHUB_WORKSPACE"/corepatch
$APKEditor d -f -i "$GITHUB_WORKSPACE"/corepatch/services.jar -o "$GITHUB_WORKSPACE"/corepatch/services 2>&1 1>&/dev/null
sudo rm -rf "$GITHUB_WORKSPACE"/corepatch/services.jar
fbynr='getMinimumSignatureSchemeVersionForTargetSdk'
sudo find "$GITHUB_WORKSPACE"/corepatch/services/smali/classes2/com/android/server/pm/ "$GITHUB_WORKSPACE"/corepatch/services/smali/classes2/com/android/server/pm/pkg/parsing/ -type f -maxdepth 1 -name "*.smali" -exec grep -H "$fbynr" {} \; | cut -d ':' -f 1 | while read i; do
  hs=$(grep -n "$fbynr" "$i" | cut -d ':' -f 1)
  sz=$(sudo tail -n +"$hs" "$i" | grep -m 1 "move-result" | tr -dc '0-9')
  hs1=$(sudo awk -v HS=$hs 'NR>=HS && /move-result /{print NR; exit}' "$i")
  hss=$hs
  sedsc="const/4 v${sz}, 0x0"
  { sudo sed -i "${hs},${hs1}d" "$i" && sudo sed -i "${hss}i\\${sedsc}" "$i"; } && echo "${i}  修改成功"
done
# 修复开机卡顿 By Weverse
info_necessary 修复开机卡顿
target_smali="$GITHUB_WORKSPACE"/corepatch/services/smali/classes/com/android/server/display/DisplayDeviceConfig.smali
target_line=$(grep -n -E '\.method.*loadPeakDefaultRefreshRate' $target_smali | cut -d: -f1)
end_line=$(sed -n "$target_line,/^\.end method/{p;/\.end method/q}" $target_smali | wc -l)
end_line=$((target_line + end_line))
sudo sed -i "${target_line},${end_line}d" "$target_smali"
sudo sed -i "${target_line}i\\
.method private loadPeakDefaultRefreshRate(Lcom/android/server/display/config/RefreshRateConfigs;)V\\
    .registers 3\\
    .param p1, \"refreshRateConfigs\"  # Lcom/android/server/display/config/RefreshRateConfigs;\\
\\
    const v0, 0x3c\\
\\
    iput v0, p0, Lcom/android/server/display/DisplayDeviceConfig;->mDefaultPeakRefreshRate:I\\
\\
    return-void\\
.end method\\
" $target_smali
$APKEditor b -f -i "$GITHUB_WORKSPACE"/corepatch/services -o "$GITHUB_WORKSPACE"/corepatch/services.jar 2>&1 1>&/dev/null
sudo mv -f "$GITHUB_WORKSPACE"/corepatch/services.jar "$GITHUB_WORKSPACE"/images/system/system/framework
sudo rm -rf "$GITHUB_WORKSPACE"/images/system/system/framework/oat/arm64/services.odex
sudo rm -rf "$GITHUB_WORKSPACE"/images/system/system/framework/oat/arm64/services.vdex
sudo rm -rf "$GITHUB_WORKSPACE"/corepatch
# K30S专属部分 By Weverses
if [[ "$device" == "apollo" ]]; then
  # 修复破音 By Weverses
  info_necessary 修复破音
  sudo unzip -o -q "$GITHUB_WORKSPACE"/apollo_files/Sound.zip -d "$GITHUB_WORKSPACE"/"$device"
  # 半修复自带相机 By Weverses
  info_necessary 半修复自带相机
  sudo mv -f "$GITHUB_WORKSPACE"/apollo_files/libmialgoengine.so "$GITHUB_WORKSPACE"/"$device"/vendor/lib64
  sudo mv -f "$GITHUB_WORKSPACE"/apollo_files/libmialgoengine2.so "$GITHUB_WORKSPACE"/"$device"/vendor/lib64
fi
# millet修复 By MeetingFate
info_necessary millet修复
Find_character "$product_build_prop" ro.millet.netlink
if [[ $Character_present == true ]]; then
  sudo sed -i 's/ro.millet.netlink=[^*]*/ro.millet.netlink=29/' "$product_build_prop"
else
  sudo sed -i ''"$(sudo sed -n '/ro.miui.notch/=' "$product_build_prop")"'a ro.millet.netlink=29' "$product_build_prop"
fi
# 修复PS手柄按键映射
info_functional 修复PS手柄按键映射
sudo sed -i '/requires_kernel_config CONFIG_HID_PLAYSTATION/s/^/#/' "$GITHUB_WORKSPACE"/images/system/system/usr/keylayout/Vendor_054c_Product_0ce6.kl
# 替换selinux By zjw2017
if [[ "$device" == "umi" ]] || [[ "$device" == "cmi" ]] || [[ "$device" == "cas" ]] || [[ "$device" == "apollo" ]]; then
  sudo rm -rf "$GITHUB_WORKSPACE"/"$device"/vendor/etc/selinux/*
  sudo unzip -o -q "$GITHUB_WORKSPACE"/"$device"_files/selinux.zip -d "$GITHUB_WORKSPACE"/"$device"/vendor/etc
fi
# 音质音效修复 By zjw2017
if [[ "$device" == "thyme" ]]; then
  info_necessary 音质音效修复
  MiSound=$(sudo find "$GITHUB_WORKSPACE"/images/product/ -type d -iname "*MiSound*")
  if [[ -n "$MiSound" ]]; then
    echo "找到文件: $MiSound"
    sudo rm -rf "$MiSound"/*
  fi
  MiSound2=${MiSound##*/}
  sudo mv "$GITHUB_WORKSPACE"/common_files/MiSound_T.apk "$MiSound"/$MiSound2.apk
fi
# 杜比全景声 By MeetingFate
  info_functional 杜比全景声
  # 植入杜比移植必须文件 By Meetingfate
  sudo unzip -o -q "$GITHUB_WORKSPACE"/common_files/dolby.zip -d "$GITHUB_WORKSPACE"/"$device"/vendor
  # 修改用户组，使杜比服务可被正常拉起 By Meetingfate
  echo "/vendor/bin/hw/vendor\.dolby\.hardware\.dms@2\.0-service u:object_r:hal_dms_default_exec:s0" | sudo tee -a "$GITHUB_WORKSPACE"/"$device"/config/vendor_file_contexts
  echo "/vendor/etc/dolby u:object_r:vendor_configs_file:s0" | sudo tee -a "$GITHUB_WORKSPACE"/"$device"/config/vendor_file_contexts
  echo "/vendor/etc/dolby/dax-default\.xml u:object_r:vendor_configs_file:s0" | sudo tee -a "$GITHUB_WORKSPACE"/"$device"/config/vendor_file_contexts
  echo "/vendor/etc/init/vendor\.dolby\.hardware\.dms@2\.0-service\.rc u:object_r:vendor_configs_file:s0" | sudo tee -a "$GITHUB_WORKSPACE"/"$device"/config/vendor_file_contexts
  echo "/vendor/etc/vintf/manifest/manifest_vendor\.dolby\.hardware\.dms\.xml u:object_r:vendor_configs_file:s0" | sudo tee -a "$GITHUB_WORKSPACE"/"$device"/config/vendor_file_contexts
  # 杜比音效支持 By Meetingfate
  #sudo sed -i ''"$(sudo sed -n '/ro.vendor.audio.soundfx.type/=' "$vendor_build_prop")"'a ro.vendor.audio.dolby.surround.enable=true' "$vendor_build_prop"
  #sudo sed -i ''"$(sudo sed -n '/ro.vendor.audio.soundfx.type/=' "$vendor_build_prop")"'i   ro.vendor.dolby.dax.version=DAX3_3.6.0.12_r1\nro.vendor.audio.dolby.dax.support=true' "$vendor_build_prop"
  # 修复杜比开关的的音质音效 By Meetingfate
  MiSound=$(sudo find "$GITHUB_WORKSPACE"/images/product/ -type d -iname "*MiSound*")
  if [[ -n "$MiSound" ]]; then
    echo "找到文件: $MiSound"
    sudo rm -rf "$MiSound"/*
  fi
  MiSound2=${MiSound##*/}
  sudo mv "$GITHUB_WORKSPACE"/common_files/MiSound_Dolby.apk "$MiSound"/$MiSound2.apk
# 完美图标 By PedroZ
info_functional 完美图标
cd ${GITHUB_WORKSPACE}
git clone https://github.com/pzcn/Perfect-Icons-Completion-Project.git icons --depth 1
for pkg in $(ls "$GITHUB_WORKSPACE"/images/product/media/theme/miui_mod_icons/dynamic/); do
  if [[ -d ${GITHUB_WORKSPACE}/icons/icons/$pkg ]]; then
    rm -rf ${GITHUB_WORKSPACE}/icons/icons/$pkg
  fi
done
rm -rf ${GITHUB_WORKSPACE}/icons/icons/com.xiaomi.scanner
mv "$GITHUB_WORKSPACE"/images/product/media/theme/default/icons "$GITHUB_WORKSPACE"/images/product/media/theme/default/icons.zip
rm -rf "$GITHUB_WORKSPACE"/images/product/media/theme/default/dynamicicons
mkdir -p ${GITHUB_WORKSPACE}/icons/res
mv ${GITHUB_WORKSPACE}/icons/icons ${GITHUB_WORKSPACE}/icons/res/drawable-xxhdpi
cd ${GITHUB_WORKSPACE}/icons
zip -qr "$GITHUB_WORKSPACE"/images/product/media/theme/default/icons.zip res
cd ${GITHUB_WORKSPACE}/icons/themes/Hyper/
zip -qr "$GITHUB_WORKSPACE"/images/product/media/theme/default/dynamicicons.zip layer_animating_icons
cd ${GITHUB_WORKSPACE}/icons/themes/common/
zip -qr "$GITHUB_WORKSPACE"/images/product/media/theme/default/dynamicicons.zip layer_animating_icons
mv "$GITHUB_WORKSPACE"/images/product/media/theme/default/icons.zip "$GITHUB_WORKSPACE"/images/product/media/theme/default/icons
mv "$GITHUB_WORKSPACE"/images/product/media/theme/default/dynamicicons.zip "$GITHUB_WORKSPACE"/images/product/media/theme/default/dynamicicons
rm -rf ${GITHUB_WORKSPACE}/icons
cd ${GITHUB_WORKSPACE}
echo 客制化build.prop
# 修改build.prop By zjw2017
sudo sed -i -e 's/'"$origin_date"'/'"$date2"'/' "$system_dlkm_build_prop" \
  "$system_build_prop" "$system_ext_build_prop" "$product_build_prop"
sudo sed -i -e 's/'"$origin_bottom_date"'/'"$date2"'/' "$vendor_build_prop" "$odm_build_prop"
sudo sed -i 's/'"$os_date"'/'"$date"'/' "$mi_ext_build_prop"
if [[ "$device" == "alioth" ]]; then
  sudo sed -i -e 's/'"$origin_bottom_date"'/'"$date2"'/' \
    "$GITHUB_WORKSPACE"/"$device"/vendor/std.build.prop "$GITHUB_WORKSPACE"/"$device"/vendor/pro.build.prop \
    "$GITHUB_WORKSPACE"/"$device"/odm/etc/std.build.prop "$GITHUB_WORKSPACE"/"$device"/odm/etc/pro.build.prop
fi
sudo sed -i -e 's/'"$target_device"'/'"$device"'/' "$product_build_prop" "$mi_ext_build_prop"
sudo sed -i -e 's/'"$device"':13/'"$device"':14/' "$vendor_build_prop" "$odm_build_prop"
if [[ "$device" == "umi" ]]; then
  sudo sed -i -e 's/U[A-Z][A-Z]CNXM/UJBCNXM/' "$system_dlkm_build_prop" "$mi_ext_build_prop" \
    "$system_build_prop" "$system_ext_build_prop" "$product_build_prop" \
    "$vendor_build_prop" "$odm_build_prop"
elif [[ "$device" == "cmi" ]]; then
  sudo sed -i -e 's/U[A-Z][A-Z]CNXM/UJACNXM/' "$system_dlkm_build_prop" "$mi_ext_build_prop" \
    "$system_build_prop" "$system_ext_build_prop" "$product_build_prop" \
    "$vendor_build_prop" "$odm_build_prop"
elif [[ "$device" == "cas" ]]; then
  sudo sed -i -e 's/U[A-Z][A-Z]CNXM/UJJCNXM/' "$system_dlkm_build_prop" "$mi_ext_build_prop" \
    "$system_build_prop" "$system_ext_build_prop" "$product_build_prop" \
    "$vendor_build_prop" "$odm_build_prop"
elif [[ "$device" == "apollo" ]]; then
  sudo sed -i -e 's/U[A-Z][A-Z]CNXM/UJDCNXM/' "$system_dlkm_build_prop" "$mi_ext_build_prop" \
    "$system_build_prop" "$system_ext_build_prop" "$product_build_prop" \
    "$vendor_build_prop" "$odm_build_prop"
elif [[ "$device" == "alioth" ]]; then
  sudo sed -i -e 's/U[A-Z][A-Z]CNXM/UKHCNXM/' "$system_dlkm_build_prop" "$mi_ext_build_prop" \
    "$system_build_prop" "$system_ext_build_prop" "$product_build_prop" \
    "$vendor_build_prop" "$odm_build_prop" \
    "$GITHUB_WORKSPACE"/"$device"/vendor/std.build.prop "$GITHUB_WORKSPACE"/"$device"/vendor/pro.build.prop \
    "$GITHUB_WORKSPACE"/"$device"/odm/etc/std.build.prop "$GITHUB_WORKSPACE"/"$device"/odm/etc/pro.build.prop
  sudo sed -i -e 's/'"$device"':13/'"$device"':14/' "$GITHUB_WORKSPACE"/"$device"/vendor/pro.build.prop "$GITHUB_WORKSPACE"/"$device"/odm/etc/pro.build.prop
  sudo sed -i -e 's/'"$device"'in:13/'"$device"'in:14/' "$GITHUB_WORKSPACE"/"$device"/vendor/std.build.prop "$GITHUB_WORKSPACE"/"$device"/odm/etc/std.build.prop
elif [[ "$device" == "thyme" ]]; then
  sudo sed -i -e 's/U[A-Z][A-Z]CNXM/UGACNXM/' "$system_dlkm_build_prop" "$mi_ext_build_prop" \
    "$system_build_prop" "$system_ext_build_prop" "$product_build_prop" \
    "$vendor_build_prop" "$odm_build_prop"
fi
build_time=$(date) && build_utc=$(date -d "$build_time" +%s)
sudo sed -i 's/ro.build.user=[^*]*/ro.build.user=yzdhz/' "$system_build_prop"
sudo sed -i 's/ro.build.host=[^*]*/ro.build.host='"$host"'/' "$system_build_prop"
sudo sed -i 's/ro.build.version.base_os=[^*]*/ro.build.version.base_os=Weverses-zjw2017-Meetingfate-TheVoyager0777/' "$system_build_prop"
sudo sed -i 's/ro.system.build.date=[^*]*/ro.system.build.date='"$build_time"'/' "$system_build_prop"
sudo sed -i 's/ro.system.build.date.utc=[^*]*/ro.system.build.date.utc='"$build_utc"'/' "$system_build_prop"
sudo sed -i 's/ro.system_dlkm.build.date=[^*]*/ro.system_dlkm.build.date='"$build_time"'/' "$system_dlkm_build_prop"
sudo sed -i 's/ro.system_dlkm.build.date.utc=[^*]*/ro.system_dlkm.build.date.utc='"$build_utc"'/' "$system_dlkm_build_prop"
sudo sed -i 's/ro.build.date=[^*]*/ro.build.date='"$build_time"'/' "$system_build_prop"
sudo sed -i 's/ro.build.date.utc=[^*]*/ro.build.date.utc='"$build_utc"'/' "$system_build_prop"
sudo sed -i 's/ro.vendor.build.date=[^*]*/ro.vendor.build.date='"$build_time"'/' "$vendor_build_prop"
sudo sed -i 's/ro.vendor.build.date.utc=[^*]*/ro.vendor.build.date.utc='"$build_utc"'/' "$vendor_build_prop"
sudo sed -i 's/ro.bootimage.build.date=[^*]*/ro.bootimage.build.date='"$build_time"'/' "$vendor_build_prop"
sudo sed -i 's/ro.bootimage.build.date.utc=[^*]*/ro.bootimage.build.date.utc='"$build_utc"'/' "$vendor_build_prop"
sudo sed -i 's/ro.system_ext.build.date=[^*]*/ro.system_ext.build.date='"$build_time"'/' "$system_ext_build_prop"
sudo sed -i 's/ro.system_ext.build.date.utc=[^*]*/ro.system_ext.build.date.utc='"$build_utc"'/' "$system_ext_build_prop"
sudo sed -i 's/ro.product.build.date=[^*]*/ro.product.build.date='"$build_time"'/' "$product_build_prop"
sudo sed -i 's/ro.product.build.date.utc=[^*]*/ro.product.build.date.utc='"$build_utc"'/' "$product_build_prop"
sudo sed -i 's/ro.odm.build.date=[^*]*/ro.odm.build.date='"$build_time"'/' "$odm_build_prop"
sudo sed -i 's/ro.odm.build.date.utc=[^*]*/ro.odm.build.date.utc='"$build_utc"'/' "$odm_build_prop"
sudo sed -i -e 's/'"$bottom_base_line"'/'"$target_base_line"'/' "$vendor_build_prop" "$odm_build_prop"
if [[ "$device" == "alioth" ]]; then
  sudo sed -i -e 's/'"$bottom_base_line"'/'"$target_base_line"'/' \
    "$GITHUB_WORKSPACE"/"$device"/vendor/pro.build.prop \
    "$GITHUB_WORKSPACE"/"$device"/vendor/std.build.prop \
    "$GITHUB_WORKSPACE"/"$device"/odm/etc/pro.build.prop \
    "$GITHUB_WORKSPACE"/"$device"/odm/etc/std.build.prop
fi
# 杜比视界 By MeetingFate
sudo sed -i ''"$(sudo sed -n '/ro.vendor.audio.soundfx.type/=' "$vendor_build_prop")"'a ro.vendor.audio.dolby.vision.support=true' "$vendor_build_prop"
sudo sed -i 's/ro.vendor.audio.dolby.vision.support=[^*]*/ro.vendor.audio.dolby.vision.support=true/' "$vendor_build_prop"
sudo sed -i ''"$(sudo sed -n '/ro.millet.netlink/=' "$product_build_prop")"'a debug.config.media.video.dolby_vision_suports=true' "$product_build_prop"
sudo sed -i 's/debug.config.media.video.dolby_vision_suports=[^*]*/debug.config.media.video.dolby_vision_suports=true/' "$product_build_prop"
Find_character "$product_build_prop" ro.video.dolby_vision_omx
if [[ $Character_present == true ]]; then
  sudo sed -i 's/ro.video.dolby_vision_omx=[^*]*/ro.video.dolby_vision_omx=true/' "$product_build_prop"
else
  sudo sed -i ''"$(sudo sed -n '/ro.millet.netlink/=' "$product_build_prop")"'a ro.video.dolby_vision_omx=true' "$product_build_prop"
fi
# 电池健康度 By zjw2017
sudo sed -i ''"$(sudo sed -n '/ro.vendor.audio.soundfx.type/=' "$vendor_build_prop")"'a persist.vendor.battery.health=true' "$vendor_build_prop"
sudo sed -i 's/persist.vendor.battery.health=[^*]*/persist.vendor.battery.health=true/g' "$vendor_build_prop"
# 新版触感UI By MeetingFate
sudo sed -i ''"$(sudo sed -n '/ro.vendor.audio.soundfx.type/=' "$vendor_build_prop")"'a sys.haptic.slide_version=2.0' "$vendor_build_prop"
# 游戏预加载加速
sudo sed -i ''"$(sudo sed -n '/ro.millet.netlink/=' "$product_build_prop")"'a debug.game.video.support=true' "$product_build_prop"
sudo sed -i ''"$(sudo sed -n '/ro.millet.netlink/=' "$product_build_prop")"'a debug.game.video.speed=true' "$product_build_prop"
# 恢复音质音效场景选择
sudo sed -i 's/ro.vendor.audio.sfx.scenario=[^*]*/ro.vendor.audio.sfx.scenario=true/g' "$vendor_build_prop"
# 修复HEIC解码
Find_character "$vendor_build_prop" vendor.mm.enable.qcom_parser
if [[ $Character_present == true ]]; then
  sudo sed -i 's/vendor.mm.enable.qcom_parser=[^*]*/vendor.mm.enable.qcom_parser=12565751/' "$vendor_build_prop"
else
  sudo sed -i ''"$(sed -n '/ro.miui.notch/=' "$vendor_build_prop")"'a vendor.mm.enable.qcom_parser=12565751' "$vendor_build_prop"
fi
# 优化流畅度，跟手 By MeetingFate
Find_character "$product_build_prop" ro.miui.surfaceflinger_affinity
if [[ $Character_present == true ]]; then
  sudo sed -i 's/ro.miui.surfaceflinger_affinity=[^*]*/ro.miui.surfaceflinger_affinity=true/' "$product_build_prop"
else
  sudo sed -i ''"$(sed -n '/ro.miui.notch/=' "$product_build_prop")"'a ro.miui.surfaceflinger_affinity=true' "$product_build_prop"
fi
Find_character "$product_build_prop" persist.sys.miui_animator_sched.bigcores
if [[ $Character_present == true ]]; then
  sudo sed -i 's/persist.sys.miui_animator_sched.bigcores=[^*]*/persist.sys.miui_animator_sched.bigcores=4-7/' "$product_build_prop"
else
  sudo sed -i ''"$(sed -n '/ro.miui.notch/=' "$product_build_prop")"'a persist.sys.miui_animator_sched.bigcores=4-7' "$product_build_prop"
fi
Find_character "$product_build_prop" persist.sys.miui_animator_sched.sched_threads
if [[ $Character_present == true ]]; then
  sudo sed -i 's/persist.sys.miui_animator_sched.sched_threads=[^*]*/persist.sys.miui_animator_sched.sched_threads=2/' "$product_build_prop"
else
  sudo sed -i ''"$(sed -n '/persist.sys.miui_animator_sched.bigcores/=' "$product_build_prop")"'a persist.sys.miui_animator_sched.sched_threads=2' "$product_build_prop"
fi
Find_character "$product_build_prop" persist.sys.miui.sf_cores
if [[ $Character_present == true ]]; then
  sudo sed -i 's/persist.sys.miui.sf_cores=[^*]*/persist.sys.miui.sf_cores=4-7/' "$product_build_prop"
else
  sudo sed -i ''"$(sed -n '/persist.sys.miui_animator_sched.sched_threads/=' "$product_build_prop")"'a persist.sys.miui.sf_cores=4-7' "$product_build_prop"
fi
Find_character "$product_build_prop" persist.sys.minfree_def
if [[ $Character_present == true ]]; then
  sudo sed -i 's/persist.sys.minfree_def=[^*]*/persist.sys.minfree_def=73728,92160,110592,154832,482560,579072/' "$product_build_prop"
else
  sudo sed -i ''"$(sed -n '/persist.sys.miui_animator_sched.big_prime_cores/=' "$product_build_prop")"'a persist.sys.minfree_def=73728,92160,110592,154832,482560,579072' "$product_build_prop"
fi
Find_character "$product_build_prop" persist.sys.minfree_6g
if [[ $Character_present == true ]]; then
  sudo sed -i 's/persist.sys.minfree_6g=[^*]*/persist.sys.minfree_6g=73728,92160,110592,258048,663552,903168/' "$product_build_prop"
else
  sudo sed -i ''"$(sed -n '/persist.sys.minfree_def/=' "$product_build_prop")"'a persist.sys.minfree_6g=73728,92160,110592,258048,663552,903168' "$product_build_prop"
fi
Find_character "$product_build_prop" persist.sys.minfree_8g
if [[ $Character_present == true ]]; then
  sudo sed -i 's/persist.sys.minfree_8g=[^*]*/persist.sys.minfree_8g=73728,92160,110592,387072,1105920,1451520/' "$product_build_prop"
else
  sudo sed -i ''"$(sed -n '/persist.sys.minfree_6g/=' "$product_build_prop")"'a persist.sys.minfree_8g=73728,92160,110592,387072,1105920,1451520' "$product_build_prop"
fi
# 专属prop By zjw2017
if [[ "$device" == "umi" ]]; then
  sudo sed -i ''"$(sudo sed -n '/ro.miui.has_gmscore/=' "$product_build_prop")"'a ro.display.screen_type=1' "$product_build_prop"
  sudo sed -i ''"$(sudo sed -n '/ro.miui.has_gmscore/=' "$product_build_prop")"'a vendor.mm.enable.qcom_parser=16776951' "$product_build_prop"
elif [[ "$device" == "cmi" ]]; then
  sudo sed -i ''"$(sudo sed -n '/ro.miui.has_gmscore/=' "$product_build_prop")"'a ro.display.screen_type=1' "$product_build_prop"
  sudo sed -i ''"$(sudo sed -n '/ro.miui.has_gmscore/=' "$product_build_prop")"'a vendor.mm.enable.qcom_parser=16776951' "$product_build_prop"
elif [[ "$device" == "cas" ]]; then
  sudo sed -i ''"$(sudo sed -n '/ro.miui.has_gmscore/=' "$product_build_prop")"'a ro.miui.vicegwsd=true' "$product_build_prop"
  # 关闭dfps By pzcn
  sudo sed -i 's/^\(ro\.vendor\.smart_dfps\)/# \1/' "$vendor_build_prop"
fi
echo 包体基础修改
if [[ "$bottom_soc" == "865" ]]; then
  sudo rm -rf "$GITHUB_WORKSPACE"/"$device"/vendor/recovery-from-boot.p
  sudo rm -rf "$GITHUB_WORKSPACE"/"$device"/vendor/bin/install-recovery.sh
  mv "$GITHUB_WORKSPACE"/tools/flashtools.zip "$GITHUB_WORKSPACE"/tools/flashtools_"$device".zip
fi
sudo unzip -o -q "$GITHUB_WORKSPACE"/tools/flashtools_"$device".zip -d "$GITHUB_WORKSPACE"/images
Find_character "$GITHUB_WORKSPACE"/images/FlashWindows.bat mod_device
if [[ $Character_present == true ]]; then
  sudo sed -i 's/mod_device/'"$device"'/' "$GITHUB_WORKSPACE"/images/FlashWindows.bat
fi
sudo mv "$GITHUB_WORKSPACE"/"$device"/firmware-update "$GITHUB_WORKSPACE"/images
sudo mv -f "$GITHUB_WORKSPACE"/common_files/super_empty.zst "$GITHUB_WORKSPACE"/images/firmware-update
sudo cp -r "$GITHUB_WORKSPACE"/"$device"/* "$GITHUB_WORKSPACE"/images
sudo rm -rf "$GITHUB_WORKSPACE"/"$device"
sudo rm -rf "$GITHUB_WORKSPACE"/common_files
for device in umi cmi cas apollo thyme alioth; do
  sudo rm -rf "$GITHUB_WORKSPACE"/"$device"_files
done
if [[ "$pack_type" == "erofs" ]]; then
  for i in product vendor system odm system_ext mi_ext; do
    echo "正在合成$i"
    sudo python3 "$GITHUB_WORKSPACE"/tools/python/fspatch.py "$GITHUB_WORKSPACE"/images/$i "$GITHUB_WORKSPACE"/images/config/"$i"_fs_config
    sudo python3 "$GITHUB_WORKSPACE"/tools/python/contextpatch.py "$GITHUB_WORKSPACE"/images/$i "$GITHUB_WORKSPACE"/images/config/"$i"_file_contexts
    sudo "$GITHUB_WORKSPACE"/tools/binary/mkfs.erofs -zlz4hc,9 -T 1230768000 --quiet --mount-point /$i --fs-config-file "$GITHUB_WORKSPACE"/images/config/"$i"_fs_config --file-contexts "$GITHUB_WORKSPACE"/images/config/"$i"_file_contexts "$GITHUB_WORKSPACE"/images/$i.img "$GITHUB_WORKSPACE"/images/$i
    eval "$i"_size=$(du -sb "$GITHUB_WORKSPACE"/images/$i.img | awk {'print $1'})
    sudo rm -rf "$GITHUB_WORKSPACE"/images/$i
  done
  sudo rm -rf "$GITHUB_WORKSPACE"/images/config
fi
if [[ "$pack_type" == "ext4" ]]; then
  # 0B打包 By Meetingfate
  img_free() {
    size_free="$(tune2fs -l "$GITHUB_WORKSPACE"/images/"$1".img | awk '/Free blocks:/ { print $3 }')"
    size_free="$(echo "$size_free / 4096 * 1024 * 1024" | bc)"
    if [[ $size_free -ge 1073741824 ]]; then
      File_Type=$(awk "BEGIN{print $size_free/1073741824}")G
    elif [[ $size_free -ge 1048576 ]]; then
      File_Type=$(awk "BEGIN{print $size_free/1048576}")MB
    elif [[ $size_free -ge 1024 ]]; then
      File_Type=$(awk "BEGIN{print $size_free/1024}")kb
    elif [[ $size_free -le 1024 ]]; then
      File_Type=${size_free}b
    fi
    echo "- $1剩余空间：$File_Type"
  }
  for i in product vendor system odm system_ext mi_ext; do
    eval "$i"_size_orig=$(sudo du -sb "$GITHUB_WORKSPACE"/images/"$i" | awk {'print $1'})
    if [[ "$(eval echo "$"$i"_size_orig")" -lt "104857600" ]]; then
      size=$(echo "$(eval echo "$"$i"_size_orig") * 15 / 10 / 4096 * 4096" | bc)
    elif [[ "$(eval echo "$"$i"_size_orig")" -lt "1073741824" ]]; then
      size=$(echo "$(eval echo "$"$i"_size_orig") * 108 / 100 / 4096 * 4096" | bc)
    else
      size=$(echo "$(eval echo "$"$i"_size_orig") * 103 / 100 / 4096 * 4096" | bc)
    fi
    eval "$i"_size=$size
  done
  system_size=$(echo "$system_size * 4096 / 4096 / 4096" | bc)
  vendor_size=$(echo "$vendor_size * 4096 / 4096 / 4096" | bc)
  product_size=$(echo "$product_size * 4096 / 4096 / 4096" | bc)
  odm_size=$(echo "$odm_size * 4096 / 4096 / 4096" | bc)
  system_ext_size=$(echo "$system_ext_size * 4096 / 4096 / 4096" | bc)
  mi_ext_size=$(echo "$mi_ext_size * 4096 / 4096 / 4096" | bc)
  for i in mi_ext odm product system system_ext vendor; do
    mkdir -p "$GITHUB_WORKSPACE"/images/$i/lost+found
    sudo touch -t 200901010000.00 "$GITHUB_WORKSPACE"/images/$i/lost+found
  done
  for i in mi_ext odm product system system_ext vendor; do
    echo "正在合成$i"
    sudo python3 "$GITHUB_WORKSPACE"/tools/python/fspatch.py "$GITHUB_WORKSPACE"/images/$i "$GITHUB_WORKSPACE"/images/config/"$i"_fs_config
    sudo python3 "$GITHUB_WORKSPACE"/tools/python/contextpatch.py "$GITHUB_WORKSPACE"/images/$i "$GITHUB_WORKSPACE"/images/config/"$i"_file_contexts
    eval "$i"_inode=$(sudo cat "$GITHUB_WORKSPACE"/images/config/"$i"_fs_config | wc -l)
    eval "$i"_inode=$(echo "$(eval echo "$"$i"_inode") + 8" | bc)
    "$GITHUB_WORKSPACE"/tools/binary/mke2fs -O ^has_journal -L $i -I 256 -N $(eval echo "$"$i"_inode") -M /$i -m 0 -t ext4 -b 4096 "$GITHUB_WORKSPACE"/images/$i.img $(eval echo "$"$i"_size") || false
    sudo "$GITHUB_WORKSPACE"/tools/binary/e2fsdroid -e -T 1230768000 -C "$GITHUB_WORKSPACE"/images/config/"$i"_fs_config -S "$GITHUB_WORKSPACE"/images/config/"$i"_file_contexts -f "$GITHUB_WORKSPACE"/images/$i -a /$i "$GITHUB_WORKSPACE"/images/$i.img || false
    resize2fs -f -M "$GITHUB_WORKSPACE"/images/$i.img
    eval "$i"_size=$(du -sb "$GITHUB_WORKSPACE"/images/$i.img | awk {'print $1'})
    img_free "$i"
    if [[ $i == mi_ext ]]; then
      sudo rm -rf "$GITHUB_WORKSPACE"/images/$i
      continue
    fi
    size_free=$(tune2fs -l "$GITHUB_WORKSPACE"/images/$i.img | awk '/Free blocks:/ { print $3}')
    if [[ "$size_free" != 0 ]]; then
      size_free=$(echo "$size_free * 4096" | bc)
      eval "$i"_size=$(echo "$(eval echo "$"$i"_size") - $size_free" | bc)
      eval "$i"_size=$(echo "$(eval echo "$"$i"_size") * 4096 / 4096 / 4096" | bc)
      sudo rm -rf "$GITHUB_WORKSPACE"/images/$i.img
      echo "第二次合成$i"
      "$GITHUB_WORKSPACE"/tools/binary/mke2fs -O ^has_journal -L $i -I 256 -N $(eval echo "$"$i"_inode") -M /$i -m 0 -t ext4 -b 4096 "$GITHUB_WORKSPACE"/images/$i.img $(eval echo "$"$i"_size") || false
      sudo "$GITHUB_WORKSPACE"/tools/binary/e2fsdroid -e -T 1230768000 -C "$GITHUB_WORKSPACE"/images/config/"$i"_fs_config -S "$GITHUB_WORKSPACE"/images/config/"$i"_file_contexts -f "$GITHUB_WORKSPACE"/images/$i -a /$i "$GITHUB_WORKSPACE"/images/$i.img || false
      resize2fs -f -M "$GITHUB_WORKSPACE"/images/$i.img
      eval "$i"_size=$(du -sb "$GITHUB_WORKSPACE"/images/$i.img | awk {'print $1'})
      img_free "$i"
    fi
    sudo rm -rf "$GITHUB_WORKSPACE"/images/$i
  done
  sudo rm -rf "$GITHUB_WORKSPACE"/images/config
  sudo rm -rf "$GITHUB_WORKSPACE"/images/mi_ext
fi
if [[ "$bottom_soc" == "865" ]]; then
  "$GITHUB_WORKSPACE"/tools/binary/lpmake --device super:9126805504 \
    --metadata-size 65536 --super-name super --block-size 4096 --metadata-slots 2 \
    --partition odm:readonly:"$odm_size":qti_dynamic_partitions --image odm="$GITHUB_WORKSPACE"/images/odm.img \
    --partition product:readonly:"$product_size":qti_dynamic_partitions --image product="$GITHUB_WORKSPACE"/images/product.img \
    --partition mi_ext:readonly:"$mi_ext_size":qti_dynamic_partitions --image mi_ext="$GITHUB_WORKSPACE"/images/mi_ext.img \
    --partition system:readonly:"$system_size":qti_dynamic_partitions --image system="$GITHUB_WORKSPACE"/images/system.img \
    --partition system_ext:readonly:"$system_ext_size":qti_dynamic_partitions --image system_ext="$GITHUB_WORKSPACE"/images/system_ext.img \
    --partition vendor:readonly:"$vendor_size":qti_dynamic_partitions --image vendor="$GITHUB_WORKSPACE"/images/vendor.img \
    --group qti_dynamic_partitions:9126805504 -F --output "$GITHUB_WORKSPACE"/images/super.img
elif [[ "$bottom_soc" == "870" ]]; then
  "$GITHUB_WORKSPACE"/tools/binary/lpmake --device super:9126805504 --virtual-ab \
    --metadata-size 65536 --super-name super --block-size 4096 --metadata-slots 3 \
    --partition odm_a:readonly:"$odm_size":qti_dynamic_partitions_a --image odm_a="$GITHUB_WORKSPACE"/images/odm.img \
    --partition product_a:readonly:"$product_size":qti_dynamic_partitions_a --image product_a="$GITHUB_WORKSPACE"/images/product.img \
    --partition mi_ext_a:readonly:"$mi_ext_size":qti_dynamic_partitions_a --image mi_ext_a="$GITHUB_WORKSPACE"/images/mi_ext.img \
    --partition system_a:readonly:"$system_size":qti_dynamic_partitions_a --image system_a="$GITHUB_WORKSPACE"/images/system.img \
    --partition system_ext_a:readonly:"$system_ext_size":qti_dynamic_partitions_a --image system_ext_a="$GITHUB_WORKSPACE"/images/system_ext.img \
    --partition vendor_a:readonly:"$vendor_size":qti_dynamic_partitions_a --image vendor_a="$GITHUB_WORKSPACE"/images/vendor.img \
    --partition mi_ext_b:readonly:0:qti_dynamic_partitions_b \
    --partition product_b:readonly:0:qti_dynamic_partitions_b \
    --partition system_b:readonly:0:qti_dynamic_partitions_b \
    --partition vendor_b:readonly:0:qti_dynamic_partitions_b \
    --partition system_ext_b:readonly:0:qti_dynamic_partitions_b \
    --partition odm_b:readonly:0:qti_dynamic_partitions_b \
    --group qti_dynamic_partitions_a:9126805504 --group qti_dynamic_partitions_b:9126805504 -F --output "$GITHUB_WORKSPACE"/images/super.img
fi
for i in product system system_ext vendor odm mi_ext; do
  rm -rf "$GITHUB_WORKSPACE"/images/$i.img
done
sudo find "$GITHUB_WORKSPACE"/images/ -exec touch -t 200901010000.00 {} \;
"$GITHUB_WORKSPACE"/tools/binary/zstd -9 -f "$GITHUB_WORKSPACE"/images/super.img -o "$GITHUB_WORKSPACE"/images/super.zst --rm
sudo 7z a "$GITHUB_WORKSPACE"/zip/miui_"$Device"_"$date".zip "$GITHUB_WORKSPACE"/images/*
sudo rm -rf "$GITHUB_WORKSPACE"/images
md5=$(md5sum "$GITHUB_WORKSPACE"/zip/miui_"$Device"_"$date".zip)
zipmd5=${md5:0:10}
if [[ "$pack_type" == "erofs" ]]; then
  NEW_PACKAGE_NAME=miui_"$Device"_"$date"_"$zipmd5"_14.0_2in1_EROFS.zip
elif [[ "$pack_type" == "ext4" ]]; then
  NEW_PACKAGE_NAME=miui_"$Device"_"$date"_"$zipmd5"_14.0_2in1.zip
fi
mv "$GITHUB_WORKSPACE"/zip/miui_"$Device"_"$date".zip "$GITHUB_WORKSPACE"/zip/$NEW_PACKAGE_NAME
sudo rm -rf "$GITHUB_WORKSPACE"/common_files "$GITHUB_WORKSPACE"/tools LICENSE
{
  echo "MD5=${md5:0:32}"
  echo "NEW_PACKAGE_NAME=$NEW_PACKAGE_NAME"
  echo "bottom_os_date=$bottom_os_date"
  echo "bottom_security_patch=$bottom_security_patch"
  echo "bottom_base_line=$bottom_base_line"
  echo "target_os_date=$os_date"
  echo "target_security_patch=$target_security_patch"
  echo "target_base_line=$target_base_line"
} >>"$GITHUB_WORKSPACE"/PackageInfo.txt
sudo chmod -R 777 "$GITHUB_WORKSPACE"
