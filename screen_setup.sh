#!/bin/bash
BLACKLIST="/etc/modprobe.d/raspi-blacklist.conf"
CONFIG="/boot/config.txt"
CMDLINE="/boot/cmdline.txt"
FONT="ProFont6x11"
FBCP="/usr/local/bin/fbcp"
SPEED="80000000"
ROTATE="90"
FPS="60"
RESOLUTION="640x480"
RESOLUTION_TEMP="640x480"
HDMIGROUP="2"
HDMIMODE="4"
HDMICVT=""
OUTPUT_DEVICE="BOTH"
SCREEN_BLANKING="No"
TITLE="Geekworm WORKSHOP"
BACKTITLE="Geekworm.com"
DEVICE="2.2"
TRANSFORM_24r0="0.988809 -0.023645 0.060523 -0.028817 1.003935 0.034176 0 0 1"
TRANSFORM_24r90="0.014773 -1.132874 1.033662 1.118701 0.009656 -0.065273 0 0 1"
TRANSFORM_24r180="-1.115235 -0.010589 1.057967 -0.005964 -1.107968 1.025780 0 0 1"
TRANSFORM_24r270="-0.033192 1.126869 -0.014114 -1.115846 0.006580 1.050030 0 0 1"
TRANSFORM=$TRANSFORM_24r270
SOFTWARE_LIST="xserver-xorg-input-evdev xserver-xorg-input-libinput python-dev python-pip python-smbus python-wxgtk3.0 matchbox-keyboard"
FILE_FBTURBO="/etc/X11/xorg.conf.d/99-fbturbo.conf"
FILE_CALIBRATION="/etc/X11/xorg.conf.d/99-calibration.conf"
XRANDRSETTINGS="/etc/X11/Xsession.d/45-custom_xrandr-settings"
DI_OUTPUTDEVICE=1
DI_RESOLUTION=1
DI_ROTATE=1
DI_SPEED=1
DI_BLANKING=1
DI_DEVICESELECT=1
DI_22_24=1

function check_sysreq(){
	SOFT=$(dpkg -l $SOFTWARE_LIST | grep "un  ")
	if [ -n "$SOFT" ]; then
		apt update
		apt -y install $SOFTWARE_LIST
	fi
}

# Enable tft in config.txt
function enable_tft_config(){
	echo "dtparam=i2c_arm=on" >> $CONFIG
	echo "dtparam=spi=on" >> $CONFIG
	if [ "$DEVICE" == "2.2" ]; then
		echo "dtoverlay=pitft22,speed=$SPEED,rotate=$ROTATE,fps=$FPS" >> $CONFIG
	elif [ "$DEVICE" == "2.4" ]; then
		echo "dtoverlay=pitft28-resistive,speed=$SPEED,rotate=$ROTATE,fps=$FPS" >> $CONFIG
	fi
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

# Disable tft in config.txt
function disable_tft_config(){
	sed -i '/^dtparam=spi/d' $CONFIG
	sed -i '/^dtparam=i2c_arm=/d' $CONFIG
	sed -i '/^dtoverlay=pitft/d' $CONFIG
	sed -i '/^hdmi_mode=/d' $CONFIG
	sed -i '/^hdmi_group=/d' $CONFIG
	sed -i '/^hdmi_cvt=/d' $CONFIG
	sed -i '/^hdmi_force_hotplug=/d' $CONFIG
}

function enable_tft_cmdline(){
	FBONCONFIGED=$(cat /boot/cmdline.txt | grep "fbcon=map:10")
	if [ -z "$FBONCONFIGED" ]; then
		sed -i -e 's/rootwait/rootwait fbcon=map:10 fbcon=font:'$FONT'/' $CMDLINE
	fi
}

function disable_tft_cmdline(){
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

function enable_tft_x(){
	if [ -e "$FILE_FBTURBO" ] ; then
		rm $FILE_FBTURBO
	fi
	touch $FILE_FBTURBO
	cat << EOF > $FILE_FBTURBO
Section "Device"
  Identifier "Adafruit PiTFT"
  Driver "fbdev"
  Option "fbdev" "/dev/fb1"
EndSection
EOF
}

function disable_tft_x(){
	if [ -e "$FILE_FBTURBO" ] ; then
		rm $FILE_FBTURBO
	fi
}

function enable_both_x(){
	echo "xrandr --output HDMI-1 --mode \"$RESOLUTION_TEMP\"" > $XRANDRSETTINGS
}

function disable_both_x(){
	if [ -f "$XRANDRSETTINGS" ]; then
		rm $XRANDRSETTINGS
	fi
}

function disable_fbcp(){
	sed -i '/^\/usr\/local\/bin\/fbcp/d' /etc/rc.local
}

function enable_fbcp(){
	if [ ! -f "$FBCP" ]; then
		if [ -f "bin/fbcp" ]; then
			chmod +x bin/fbcp
			sudo cp -a bin/fbcp $FBCP
		else
			wget https://github.com/howardqiao/zpod/raw/master/zpod_res/fbcp -O $FBCP
			chmod +x $FBCP
		fi
	else
		chmod +x $FBCP
	fi
	disable_fbcp
	sed -i '/exit 0/i\/usr\/local\/bin\/fbcp &' /etc/rc.local
}

function menu_outputdevice(){
	OPTION_OUTPUT=$(whiptail --title "OUTPUT DEVICE" \
	--backtitle "$BACKTITLE" \
	--nocancel \
	--menu "OUTPUT DEVICE:$OUTPUT_DEVICE" \
	--default-item "$DI_OUTPUTDEVICE" \
	14 60 3 \
	"1" "TFT" \
	"2" "HDMI & TFT" \
	"3" "Return" 3>&1 1>&2 2>&3)
	return $OPTION_OUTPUT
}

function menu_resolution(){
	OPTION_RES=$(whiptail --title "SCREEN RESOLUTION" \
	--backtitle "$BACKTITLE" \
	--nocancel \
	--menu "Screen resolution:$RESOLUTION" \
	--default-item "$DI_RESOLUTION" \
	14 60 5 \
	"1" "1024x768" \
	"2" "800x600" \
	"3" "640x480" \
	"4" "320x240" \
	"5" "Return" 3>&1 1>&2 2>&3)
	return $OPTION_RES
}

function menu_rotate(){
	OPTION_ROTATE=$(whiptail --title "SCREEN ROTATE" \
	--menu "Screen rotate:$ROTATE°" \
	--backtitle "$BACKTITLE" \
	--nocancel \
	--default-item "$DI_ROTATE" \
	14 60 5 \
	"1" "0°" \
	"2" "90°" \
	"3" "180°" \
	"4" "270°" \
	"5" "Return" 3>&1 1>&2 2>&3)
	return $OPTION_ROTATE
}
function menu_speed(){
	OPTION_ROTATE=$(whiptail --title "SPI SPEED" \
	--menu "SPI bus speed:$SPEED°" \
	--backtitle "$BACKTITLE" \
	--nocancel \
	--default-item "$DI_SPEED" \
	14 60 5 \
	"1" "80000000" \
	"2" "72000000" \
	"3" "64000000" \
	"4" "64000000" \
	"5" "Return" 3>&1 1>&2 2>&3)
	return $OPTION_ROTATE
}

function menu_blanking(){
	OPTION_BLANKING=$(whiptail --title "SCREEN BLANKING" \
	--menu "Screen blanking:$SCREEN_BLANKING" \
	--backtitle "$BACKTITLE" \
	--nocancel \
	--default-item "$DI_BLANKING" \
	14 60 3 \
	"1" "Enable" \
	"2" "Disble" \
	"3" "Return" 3>&1 1>&2 2>&3)
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
	--default-item "$DI_DEVICESELECT" \
	14 60 6 \
	"1" "TFT 2.2\"" \
	"2" "TFT 2.4\"" \
	"3" "HD-TFT HAT 3.5\"" \
	"4" "HD-TFT HAT 3.5\" With Touch" \
	"5" "Reset RPi config to default" \
	"6" "Exit."  3>&1 1>&2 2>&3)
	return $OPTION
}

# Menu of parameter settings
function menu_22_24(){
	OPTION=$(whiptail --title "$TITLE" \
	--menu "TFT $DEVICE Screen parameter settings:" \
	--backtitle "$BACKTITLE" \
	--nocancel \
	--default-item "$DI_22_24" \
	14 60 7 \
	"1" "Output <$OUTPUT_DEVICE>." \
	"2" "Resolution <$RESOLUTION>." \
	"3" "Rotate <$ROTATE°>." \
	"4" "SPI Speed <$SPEED>." \
	"5" "Blanking <$SCREEN_BLANKING>." \
	"6" "Apply new settings." \
	"7" "Return."  3>&1 1>&2 2>&3)
	return $OPTION
}

function apply_tft_22_24(){
	sys_reset
	enable_tft_cmdline
	if [[ "$ROTATE" == "0" ]] || [[ "$ROTATE" == "180" ]]; then
		HDMICVT="240 320 60 1 0 0 0"
	else
		HDMICVT="320 240 60 1 0 0 0"
	fi
	enable_tft_config
	if [ ! -d "/etc/X11/xorg.conf.d" ]; then
		mkdir /etc/X11/xorg.conf.d
	fi
	enable_tft_x
	enable_both_x
	if [ "$DEVICE" == "2.4" ]; then
		generate_touch_24
	fi
	disable_fbcp
}

function apply_tft_hdmi(){
	sys_reset
	enable_tft_config
	enable_both_x
	generate_touch_24
	disable_tft_x
	enable_fbcp
}

function apply(){
	check_sysreq
	HDMIGROUP=2
	HDMIMODE=87
	if [ "$RESOLUTION" == "1024x768" ]; then
		if [[ "$ROTATE" == "0" ]] || [[ "$ROTATE" == "180" ]]; then
			HDMICVT="768 1024 60 1 0 0 0"
			RESOLUTION_TEMP="768x1024"
		else
			HDMICVT="1024 768 60 1 0 0 0"
			RESOLUTION_TEMP="1024x768"
		fi
	elif [ "$RESOLUTION" == "800x600" ]; then
		if [[ "$ROTATE" == "0" ]] || [[ "$ROTATE" == "180" ]]; then
			HDMICVT="600 800 60 1 0 0 0"
			RESOLUTION_TEMP="600x800"
		else
			HDMICVT="800 600 60 1 0 0 0"
			RESOLUTION_TEMP="800x600"
		fi
	elif [ "$RESOLUTION" == "640x480" ]; then
		if [[ "$ROTATE" == "0" ]] || [[ "$ROTATE" == "180" ]]; then
			HDMICVT="480 640 60 1 0 0 0"
			RESOLUTION_TEMP="480x640"
		else
			HDMICVT="640 480 60 1 0 0 0"
			RESOLUTION_TEMP="640x480"
		fi
	else
		if [[ "$ROTATE" == "0" ]] || [[ "$ROTATE" == "180" ]]; then
			HDMICVT="240 320 60 1 0 0 0"
			RESOLUTION_TEMP="240x320"
		else
			HDMICVT="320 240 60 1 0 0 0"
			RESOLUTION_TEMP="320x240"
		fi
	fi
	case $OUTPUT_DEVICE in
		"TFT")
		apply_tft_22_24
		;;
		"BOTH")
		apply_tft_hdmi
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

function setup_22_24(){
	while true
	do
		menu_22_24
		case $? in
			1)
			DI_22_24=1
			menu_outputdevice
			case $? in
				1)
				DI_OUTPUTDEVICE=1
				OUTPUT_DEVICE="TFT"
				RESOLUTION="320x240"
				;;
				2)
				DI_OUTPUTDEVICE=2
				OUTPUT_DEVICE="BOTH"
				RESOLUTION="640x480"
				;;
				3)
				DI_OUTPUTDEVICE=3
				;;
			esac
			;;
			2)
			DI_22_24=2
			if [ "$OUTPUT_DEVICE" == "TFT" ]; then
				RESOLUTION="320x240"
			elif [ "$OUTPUT_DEVICE" == "BOTH" ]; then
				menu_resolution
				case $? in 
					1)
					DI_RESOLUTION=1
					RESOLUTION="1024x768"
					;;
					2)
					DI_RESOLUTION=2
					RESOLUTION="800x600"
					;;
					3)
					DI_RESOLUTION=3
					RESOLUTION="640x480"
					;;
					4)
					DI_RESOLUTION=4
					RESOLUTION="320x240"
					;;
					5)
					DI_RESOLUTION=5
					;;
				esac
			else
				RESOLUTION="Auto"
			fi
			;;
			3)
			DI_22_24=3
			if [ "$OUTPUT_DEVICE" != "HDMI" ]; then
				menu_rotate
				case $? in 
					1)
					DI_ROTATE=1
					ROTATE="0"
					;;
					2)
					DI_ROTATE=2
					ROTATE="90"
					;;
					3)
					DI_ROTATE=3
					ROTATE="180"
					;;
					4)
					DI_ROTATE=4
					ROTATE="270"
					;;
					5)
					DI_ROTATE=5
					;;
				esac
			fi
			;;
			4)
			DI_22_24=4
			menu_speed
			case $? in
				1)
				DI_SPEED=1
				SPEED="80000000"
				;;
				2)
				DI_SPEED=2
				SPEED="72000000"
				;;
				3)
				DI_SPEED=3
				SPEED="64000000"
				;;
				4)
				DI_SPEED=4
				SPEED="48000000"
				;;
				5)
				DI_SPEED=5
				;;
			esac
			;;
			5)
			DI_22_24=5
			menu_blanking
			case $? in 
				1)
				DI_BLANKING=1
				SCREEN_BLANKING="Yes"
				;;
				2)
				DI_BLANKING=2
				SCREEN_BLANKING="No"
				;;
				3)
				DI_BLANKING=3
				;;
			esac
			;;
			6)
			DI_22_24=6
			apply
			;;
			7)
			DI_22_24=7
			return
			;;
		esac
	done
}

function generate_touch_24(){
	# generate calibration file according to the ratate
	if [ ! -d "/etc/X11/xorg.conf.d/" ]; then
		mkdir /etc/X11/xorg.conf.d
	fi
	case $ROTATE in
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
	cat << EOF > $FILE_CALIBRATION
Section "InputClass"
        Identifier "STMPE Touchscreen Calibration"
        MatchProduct "stmpe"
        MatchDevicePath "/dev/input/event*"
        Driver "libinput"
        Option "TransformationMatrix" "$TRANSFORM"
EndSection
EOF
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

# Reset all settings to default
function sys_reset(){
	disable_tft_config
	disable_tft_cmdline
	disable_tft_x
	disable_fbcp
}

# Permission detection
if [ $UID -ne 0 ]; then
	whiptail --title "Geekworm WORKSHOP" \
	--msgbox "Superuser privileges are required to run this script.\ne.g. \"sudo $0\"" 10 60
    exit 1
fi

#whiptail --title "$TITLE" --msgbox "Setup tools for ugeek screens.\nhttp://Geekworm.com" --backtitle "$BACKTITLE" 10 60
while true
do
	menu_deviceselect
	case $? in
		1)
		DI_DEVICESELECT=1
		DEVICE="2.2"
		setup_22_24
		;;
		2)
		DI_DEVICESELECT=2
		DEVICE="2.4"
		setup_22_24
		;;
		3)
		DI_DEVICESELECT=3
		DEVICE="3.5"
		if (whiptail --title "$TITLE" \
			yes-button "Continue" \
			no-button "Exit" \
			yesno "Install 3.5\" screen?" 10 60) then
		disable_35
		enable_35
		fi
		menu_reboot
		;;
		4)
		DI_DEVICESELECT=4
		DEVICE="3.5t"
		if (whiptail --title "$TITLE" \
			yes-button "Continue" \
			no-button "Exit" \
			yesno "Install 3.5\" screen with touch?" 10 60) then
		setup_35t
		menu_reboot
		else
			exit 1
		fi
		;;
		5)
		DI_DEVICESELECT=5
		sys_reset
		menu_reboot
		;;
		6)
		DI_DEVICESELECT=6
		echo "     [ Geekworm WORKSHOP ]"
		echo "http://Geekworm.com"		
		exit 1
		;;
	esac
done
