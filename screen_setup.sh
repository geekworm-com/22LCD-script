#!/bin/bash
BLACKLIST="/etc/modprobe.d/raspi-blacklist.conf"
CONFIG="/boot/config.txt"
CMDLINE="/boot/cmdline.txt"
FONT="ProFont6x11"
FBCP="/usr/local/bin/fbcp"
SPEED="80000000"
ROTATE="90"
FPS="60"
RESOLUTION="640*480"
HDMIGROUP="2"
HDMIMODE="4"
HDMICVT=""
OUTPUT_DEVICE="BOTH"
SCREEN_BLANKING="No"
TITLE="Geekworm WORKSHOP"
BACKTITLE="Geekworm WORKSHOP"
DEVICE="2.2"
TRANSFORM_24r0="0.988809 -0.023645 0.060523 -0.028817 1.003935 0.034176 0 0 1"
TRANSFORM_24r90="0.014773 -1.132874 1.033662 1.118701 0.009656 -0.065273 0 0 1"
TRANSFORM_24r180="-1.115235 -0.010589 1.057967 -0.005964 -1.107968 1.025780 0 0 1"
TRANSFORM_24r270="-0.033192 1.126869 -0.014114 -1.115846 0.006580 1.050030 0 0 1"
TRANSFORM=$TRANSFORM_24r270
SOFTWARE_LIST="xserver-xorg-input-evdev python-dev python-pip python-smbus python-wxgtk3.0 matchbox-keyboard"
FILE_FBTURBO="/etc/X11/xorg.conf.d/99-fbturbo.conf"

function enable_tft(){
	#enable spi:dtparam=spi=on
	#sed -i 's/.*dtparam=spi=.*/dtparam=spi=on/g' $CONFIG
	disable_tft
	sed -i '/^dtparam=spi/d' $CONFIG
	echo "dtparam=spi=on" >> $CONFIG
	echo "dtoverlay=pitft22,speed=$SPEED,rotate=$ROTATE,fps=$FPS" >> $CONFIG
	if [ -n "$HDMIGROUP" ]; then
		echo "hdmi_group=$HDMIGROUP" >> $CONFIG
	fi
	if [ -n "$HDMIMODE" ]; then
		echo "hdmi_mode=$HDMIMODE" >> $CONFIG
	fi
	if [ -n "$HDMICVT" ]; then
		echo "hdmi_cvt=$HDMICVT" >> $CONFIG
	fi
	echo "hdmi_force_hotplug=1" >> $CONFIG
}
function disable_tft(){
	#disable pitft overlay
	sed -i '/^dtoverlay=pitft22/d' $CONFIG
	sed -i '/^hdmi_mode=/d' $CONFIG
	sed -i '/^hdmi_group=/d' $CONFIG
	sed -i '/^hdmi_cvt=/d' $CONFIG
	sed -i '/^hdmi_force_hotplug=/d' $CONFIG
}
function enable_cmdline_tft(){
	FBONCONFIGED=$(cat /boot/cmdline.txt | grep "fbcon=map:10")
	if [ -z "$FBONCONFIGED" ]; then
		sed -i -e 's/rootwait/rootwait fbcon=map:10 fbcon=font:'$FONT'/' $CMDLINE
	fi
}
function disable_cmdline_tft(){
	#sed -i -e 's/rootwait fbcon=map:10 fbcon=font:VGA8x8/rootwait/' /boot/cmdline.txt
	sed -i -e 's/fbcon=map:10 //' $CMDLINE
	sed -i -e 's/fbcon=font:ProFont6x11 //' $CMDLINE
	sed -i -e 's/fbcon=font:VGA8x8 //' $CMDLINE
}
function enable_blanking(){
	disable_blanking
	sed -i '/^sh -c "TERM=linux/d' /etc/rc.local
	sed -i -e 's/^xserver-command=X -s 0 dpms/#xserver-command=X/' /etc/lightdm/lightdm.conf
}
function disable_blanking(){
	sed -i '/exit 0/ish -c "TERM=linux setterm -blank 0 >/dev/tty0"' /etc/rc.local
	sed -i -e 's/^#xserver-command=X/xserver-command=X -s 0 dpms/' /etc/lightdm/lightdm.conf
}
function enable_tftx(){
	if [ -e "/usr/share/X11/xorg.conf.d/99-fbturbo.conf" ] ; then
		rm /usr/share/X11/xorg.conf.d/99-fbturbo.conf
	fi
	touch /etc/X11/xorg.conf.d/99-fbturbo.conf
	cat << EOF > /usr/share/X11/xorg.conf.d/99-fbturbo.conf
Section "Device"
  Identifier "Adafruit PiTFT"
  Driver "fbdev"
  Option "fbdev" "/dev/fb1"
EndSection
EOF
}
function disable_tftx(){
	if [ -e "$FILE_FB_TURBO" ] ; then
		rm $FILE_FBTURBO
	fi
}
function disable_fbcp(){
	sed -i '/^\/usr\/local\/bin\/fbcp/d' /etc/rc.local
}
function enable_fbcp(){
	if [ -e "$FBCP" ]; then
		echo ""
	else
		wget https://github.com/howardqiao/zpod/raw/master/zpod_res/fbcp -O $FBCP
		chmod +x $FBCP
	fi
	disable_fbcp
	sed -i '/exit 0/i\/usr\/local\/bin\/fbcp &' /etc/rc.local
}
menu_outputdevice(){
	OPTION_OUTPUT=$(whiptail --title "OUTPUT DEVICE" \
	--backtitle "$BACKTITLE" \
	--nocancel \
	--menu "OUTPUT DEVICE:$OUTPUT_DEVICE" \
	--default-item "3" \
	14 60 3 \
	"1" "HDMI" \
	"2" "TFT Screen" \
	"3" "HDMI & TFT Screen" 3>&1 1>&2 2>&3)
	return $OPTION_OUTPUT
}
menu_resolution(){
	OPTION_RES=$(whiptail --title "SCREEN RESOLUTION" \
	--backtitle "$BACKTITLE" \
	--nocancel \
	--menu "Screen resolution:$RESOLUTION" \
	--default-item "3" \
	14 60 4 \
	"1" "Auto" \
	"2" "800*600" \
	"3" "640*480" \
	"4" "320*240" 3>&1 1>&2 2>&3)
	return $OPTION_RES
}
menu_rotate(){
	OPTION_ROTATE=$(whiptail --title "SCREEN ROTATE" \
	--menu "Screen rotate:$ROTATE°" \
	--backtitle "$BACKTITLE" \
	--nocancel \
	--default-item "2" \
	14 60 4 \
	"1" "0°" \
	"2" "90°" \
	"3" "180°" \
	"4" "270°" 3>&1 1>&2 2>&3)
	return $OPTION_ROTATE
}
function menu_blanking(){
	OPTION_BLANKING=$(whiptail --title "SCREEN BLANKING" \
	--menu "Screen blanking:$SCREEN_BLANKING" \
	--backtitle "$BACKTITLE" \
	--nocancel \
	--default-item "2" \
	14 60 2 \
	"1" "Enable" \
	"2" "Disble" 3>&1 1>&2 2>&3)
	return $OPTION_BLANKING
}
function menu_reboot(){
	if (whiptail --title "$TITLE" \
		--yes-button "Reboot" \
		--no-button "Exit" \
		--yesno "Reboot system to apply new settings?" 10 60) then
		reboot
	else
		exit 1
	fi
}
function menu_deviceselect(){
	OPTION=$(whiptail --title "$TITLE" \
	--menu "Please select your device:" \
	--backtitle "$BACKTITLE" \
	--nocancel \
	14 60 6 \
	"1" "TFT 2.2\"" \
	"2" "TFT 2.4\"" \
	"3" "Raspi HD-TFT HAT 3.5\"" \
	"4" "Raspi HD-TFT HAT 3.5\" Touchscreen" \
	"5" "Exit."  3>&1 1>&2 2>&3)
	return $OPTION
}
function menu_22(){
	OPTION=$(whiptail --title "$TITLE" \
	--menu "Select the appropriate options:" \
	--backtitle "$BACKTITLE" \
	--nocancel \
	14 60 6 \
	"1" "Output <$OUTPUT_DEVICE>." \
	"2" "Resolution <$RESOLUTION>." \
	"3" "Rotate <$ROTATE°>." \
	"4" "Blanking <$SCREEN_BLANKING>." \
	"5" "Apply new settings." \
	"6" "Exit."  3>&1 1>&2 2>&3)
	return $OPTION
}
function menu_24(){
	OPTION=$(whiptail --title "$TITLE" \
	--menu "Select the appropriate options:" \
	--backtitle "$BACKTITLE" \
	--nocancel \
	14 60 6 \
	"1" "Rotate <$ROTATE°>." \
	"2" "Apply new settings." \
	"3" "Return."  3>&1 1>&2 2>&3)
	return $OPTION
}
function apply_hdmi(){
	disable_tft
	disable_cmdline_tft
	disable_tftx
	disable_fbcp
}
function apply_tft(){
	RESOLUTION="320*240"
	HDMIGROUP="2"
	HDMIMODE="87"
	HDMICVT="320 240 60 1 0 0 0"
	enable_tft
	enable_cmdline_tft
	enable_tftx
	disable_fbcp
}
function apply_both(){
	enable_tft
	disable_cmdline_tft
	disable_tftx
	enable_fbcp
}
function apply(){
	case $OUTPUT_DEVICE in
		"HDMI")
		apply_hdmi
		;;
		"TFT")
		apply_tft
		;;
		"BOTH")
		apply_both
		;;
	esac
	case $SCREEN_BLANKING in 
		"Yes")
		enable_blanking
		;;
		"No")
		disable_blanking
		;;
	esac
	menu_reboot
}
function setup_22(){
	menu_22
	case $? in
		1)
		menu_outputdevice
		case $? in
			1)
			OUTPUT_DEVICE="HDMI"
			RESOLUTION="Auto"
			;;
			2)
			OUTPUT_DEVICE="TFT"
			RESOLUTION="320x240"
			;;
			3)
			OUTPUT_DEVICE="BOTH"
			;;
		esac
		;;
		2)
		if [ "$OUTPUT_DEVICE" = "BOTH" ]; then
			menu_resolution
			case $? in 
				1)
				RESOLUTION="Auto"
				;;
				2)
				RESOLUTION="800x600"
				;;
				3)
				RESOLUTION="640x480"
				;;
				4)
				RESOLUTION="320x240"
				;;
			esac
		fi
		;;
		3)
		if [ "$OUTPUT_DEVICE" != "HDMI" ]; then
			menu_rotate
			case $? in 
				1)
				ROTATE="0"
				;;
				2)
				ROTATE="90"
				;;
				3)
				ROTATE="180"
				;;
				4)
				ROTATE="270"
				;;
			esac
		fi
		;;
		4)
		menu_blanking
		case $? in 
			1)
			SCREEN_BLANKING="Yes"
			;;
			2)
			SCREEN_BLANKING="No"
			;;
		esac
		;;
		5)
		apply
		;;
		6)
		echo "     [ Geekworm WORKSHOP ]"
		echo "http://geekworm.com"		
		exit 1
		;;
	esac
}

function enable_tft24(){
	# dpkg -l "xserver-xorg-input-evdev"
	# sudo apt install xserver-xorg-input-evdev
	# if [ ! -d /etc/X11/xorg.conf.d ]; then
		# sudo mkdir -p /etc/X11/xorg.conf.d
	# fi
	# echo "hdmi_force_hotplug=1" >> boot/config.txt
	# echo "dtparam=i2c_arm=on" >> boot/config.txt
	# echo "dtparam=spi=on" >> boot/config.txt
	# echo "enable_uart=1" >> boot/config.txt
	echo "Setup 2.4\" screen"

	if [ -f /etc/X11/xorg.conf.d/40-libinput.conf ]; then
		echo "rm -rf /etc/X11/xorg.conf.d/40-libinput.conf"
		sudo rm -rf /etc/X11/xorg.conf.d/40-libinput.conf
	fi
	if [ ! -d /etc/X11/xorg.conf.d ]; then
		echo "mkdir -p /etc/X11/xorg.conf.d"
		sudo mkdir -p /etc/X11/xorg.conf.d
	fi

	#root_dev=`grep -oPr "root=[^\s]*" /boot/cmdline.txt | awk -F= '{printf $NF}'`
	# 修改/boot/cmdline.txt
	echo "patch cmdline.txt"
	disable_cmdline_tft
	enable_cmdline_tft

	# 修改Config文件
	echo "patch /boot/config.txt"

	sed -i '/^dtoverlay=pitft/d' $CONFIG
	sed -i '/^hdmi_mode=/d' $CONFIG
	sed -i '/^hdmi_group=/d' $CONFIG
	sed -i '/^hdmi_cvt=/d' $CONFIG
	sed -i '/^hdmi_force_hotplug=/d' $CONFIG
	sed -i '/^dtparam=i2c_arm=/d' $CONFIG
	sed -i '/^dtparam=spi=/d' $CONFIG

	echo "hdmi_force_hotplug=1" >> $CONFIG
	echo "dtparam=i2c_arm=on" >> $CONFIG
	echo "dtparam=spi=on" >> $CONFIG
	echo "dtoverlay=pitft28-resistive,rotate=$ROTATE,speed=48000000,fps=30" >> $CONFIG

	echo "generate /etc/X11/xorg.conf.d/99-calibration.conf"
	# 根据选择的方向生成校准文件
	case $Rotate in
		0)
		TRANSFORM=$TRANSFORM_24r0
		;;
		90)
		TRANSFORM=$TRANSFORM_24r90
		;;
		180)
		TRANSFORM=$TRANSFORM_24r180
		;;
		270)
		TRANSFORM=$TRANSFORM_24r270
		;;
	esac
	cat << EOF > /etc/X11/xorg.conf.d/99-calibration.conf
Section "InputClass"
        Identifier "STMPE Touchscreen Calibration"
        MatchProduct "stmpe"
        MatchDevicePath "/dev/input/event*"
        Driver "libinput"
        Option "TransformationMatrix" "$TRANSFORM"
EndSection
EOF
	echo "enable desktop"
	# 启用桌面
	enable_tftx

	# 安装xserver-xorg-input-evdev
	echo "install software"
	SOFT=$(dpkg -l $SOFTWARE_LIST | grep "<none>")
	if [ -n "$SOFT" ]; then
		apt update
		apt -y install $SOFTWARE_LIST
	fi
	#sudo dpkg -i -B ./xserver-xorg-input-evdev_2.10.5-1_armhf.deb 2> error_output.txt
	sudo cp -rf /usr/share/X11/xorg.conf.d/10-evdev.conf /usr/share/X11/xorg.conf.d/45-evdev.conf

	sudo sync
	sudo sync
	sleep 1
}
function setup_24(){
	menu_24
	case $? in
		1)
		menu_rotate
		case $? in
			1)
			ROTATE="0"
			;;
			2)
			ROTATE="90"
			;;
			3)
			ROTATE="180"
			;;
			4)
			ROTATE="270"
			;;
		esac
		setup_24
		;;
		2)
		enable_tft24
		menu_reboot
		;;
		3)
		menu_deviceselect
		;;
	esac
	return
}
function setup_35(){
	return
}

function disable_35(){
	echo "Disable screen!"
	sed -i '/^dtoverlay=i2c-gpio/d' $CONFIG
	sed -i '/^overscan_left=0/d' $CONFIG
	sed -i '/^overscan_right=0/d' $CONFIG
	sed -i '/^overscan_top=0/d' $CONFIG
	sed -i '/^overscan_bottom=0/d' $CONFIG
	sed -i '/^framebuffer_width=800/d' $CONFIG
	sed -i '/^framebuffer_height=480/d' $CONFIG
	sed -i '/^enable_dpi_lcd=1/d' $CONFIG
	sed -i '/^display_default_lcd=1/d' $CONFIG
	sed -i '/^dpi_group=2/d' $CONFIG
	sed -i '/^dpi_mode=87/d' $CONFIG
	sed -i '/^dpi_output_format=0x6f015/d' $CONFIG
	sed -i '/^display_rotate=3/d' $CONFIG
	sed -i '/^hdmi_timings=480 0 16 16 24 800 0 4 2 2 0 0 0 60 0 32000000 6/d' $CONFIG
	sed -i '/^dtoverlay=dpi18/d' $CONFIG
}

function enable_35(){
	echo "enable screen!"
	cat << EOF >> $FILE_CONFIG
dtoverlay=i2c-gpio
overscan_left=0
overscan_right=0
overscan_top=0
overscan_bottom=0
framebuffer_width=800
framebuffer_height=480
enable_dpi_lcd=1
display_default_lcd=1
dpi_group=2
dpi_mode=87
dpi_output_format=0x6f015
display_rotate=3
hdmi_timings=480 0 16 16 24 800 0 4 2 2 0 0 0 60 0 32000000 6
dtoverlay=ugeekrmp-gpio-backlight
EOF
}

function disable_35t(){
	echo "Disable screen!"
	sed -i '/^dtparam=ugeekrmp/d' $CONFIG
	sed -i '/^overscan_left=0/d' $CONFIG
	sed -i '/^overscan_right=0/d' $CONFIG
	sed -i '/^overscan_top=0/d' $CONFIG
	sed -i '/^overscan_bottom=0/d' $CONFIG
	sed -i '/^framebuffer_width=800/d' $CONFIG
	sed -i '/^framebuffer_height=480/d' $CONFIG
	sed -i '/^enable_dpi_lcd=1/d' $CONFIG
	sed -i '/^display_default_lcd=1/d' $CONFIG
	sed -i '/^dpi_group=2/d' $CONFIG
	sed -i '/^dpi_mode=87/d' $CONFIG
	sed -i '/^dpi_output_format=0x6f016/d' $CONFIG
	sed -i '/^display_rotate=0/d' $CONFIG
	sed -i '/^hdmi_timings=800 0 50 20 50 480 1 3 2 3 0 0 0 60 0 32000000 6/d' $CONFIG
	sed -i '/^dtoverlay=ugeekrmp-gpio-backlight/d' $CONFIG
	systemctl stop ugeekrmp-init
	systemctl stop ugeekrmp-touch
	systemctl disable ugeekrmp-init
	systemctl disable ugeekrmp-touch
	if [ -e "/usr/lib/systemd/system/ugeekrmp-init.service" ]; then
		rm /usr/lib/systemd/system/ugeekrmp-init.service
	fi
	if [ -e "/usr/lib/systemd/system/ugeekrmp-touch.service" ]; then
		rm /usr/lib/systemd/system/ugeekrmp-touch.service
	fi
	if [ -e "/usr/bin/ugeekrmp-init" ]; then
		rm /usr/bin/ugeekrmp-init
	fi
	if [ -e "/usr/bin/ugeekrmp-touch" ]; then
		/usr/bin/ugeekrmp-touch
	fi
}

function enable_35t(){
	echo "enable screen!"
	cat << EOF >> $FILE_CONFIG
dtoverlay=ugeekrmp
overscan_left=0
overscan_right=0
overscan_top=0
overscan_bottom=0
framebuffer_width=800
framebuffer_height=480
enable_dpi_lcd=1
display_default_lcd=1
dpi_group=2
dpi_mode=87
dpi_output_format=0x6f016
display_rotate=0
hdmi_timings=800 0 50 20 50 480 1 3 2 3 0 0 0 60 0 32000000 6
dtoverlay=ugeekrmp-gpio-backlight
EOF
	cp resources/ugeekrmp-init /usr/bin/
	cp resources/ugeekrmp-touch /usr/bin/
	cp configs/ugeekrmp-init.service /usr/lib/systemd/system
	cp configs/ugeekrmp-touch.service /usr/lib/systemd/system
	systemctl enable ugeekrmp-init
	systemctl enable ugeekrmp-touch
	systemctl start ugeekrmp-init
	systemctl start ugeekrmp-touch
}

function setup_35t(){
	echo "]Update System["
	SOFT=$(dpkg -l $SOFTWARE_LIST | grep "<none>")
	if [ -n "$SOFT" ]; then
		apt update
		apt -y install $SOFTWARE_LIST
		echo "$SOFTWARE_LIST install complete."
	else
		echo "$SOFTWARE_LIST already exists."
	fi
	SOFT=$(dpkg -l python-evdev | grep "matching")
	if [ -n "$SOFT" ]; then
		dpkg -i resources/python-evdev_0.6.4-1_armhf.deb 
		echo "python-evdev install complete."
	else
		echo "python-evdev already exists."
	fi
	SOFT=$( pip search evdev | grep "INSTALLED")
	if [ -z "$SOFT" ]; then
		pip install evdev
		echo "python-evdev install complete!"
	else
		echo "python-evdev already exists."
	fi
	SOFT=$( pip search RPi.GPIO | grep "INSTALLED")
	if [ -z "$SOFT" ]; then
		pip install RPi.GPIO
		echo "python-RPi.GPIO install complete!"
	else
		echo "python-RPi.GPIO already exists."
	fi
	disable_35t
	enable_35t
	menu_reboot
}
if [ $UID -ne 0 ]; then
	whiptail --title "UGEEK WORKSHOP" \
	--msgbox "Superuser privileges are required to run this script.\ne.g. \"sudo $0\"" 10 60
    exit 1
fi
# whiptail --title "$TITLE" --msgbox "Setup tools for Geekworm screens.\nhttp://geekworm.com" --backtitle "$BACKTITLE" 10 60
menu_deviceselect
case $? in
		1)
		DEVICE="2.2"
		setup_22
		;;
		2)
		DEVICE="2.4"
		setup_24
		;;
		3)
		DEVICE="3.5"
		if (whiptail --title "$TITLE" \
			--yes-button "Continue" \
			--no-button "Exit" \
			--yesno "Install 3.5\" screen?" 10 60) then
		disable_35
		enable_35
		fi
		menu_reboot
		;;
		4)
		DEVICE="3.5t"
		if (whiptail --title "$TITLE" \
			--yes-button "Continue" \
			--no-button "Exit" \
			--yesno "Install 3.5\" screen with touch?" 10 60) then
		setup_35t
		menu_reboot
		else
			exit 1
		fi
		;;
		5)
		exit 1
		;;
esac
