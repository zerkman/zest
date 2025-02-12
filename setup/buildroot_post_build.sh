#!/bin/sh

TARGET=output/target
SRCDIR=`dirname $0`/..

if test ! -d $TARGET/sdcard ; then
    mkdir $TARGET/sdcard
    echo "/dev/mmcblk0p1 /sdcard vfat flush,dirsync,noatime,noexec,nodev,fmask=0133,dmask=0022 0 2" >> $TARGET/etc/fstab
fi

if test ! -f $TARGET/usr/bin/zestboot ; then
cat <<EOF > $TARGET/usr/bin/zestboot
#!/bin/sh
case "\$1" in
  start)
        printf "Starting zeST: "
        /usr/bin/zeST /sdcard/zest.cfg &
        echo \$! > /var/run/zest.pid
        [ \$? = 0 ] && echo "OK" || echo "FAIL"
        ;;
  stop)
        printf "Stopping zeST: "
        /bin/kill \`/bin/cat /var/run/zest.pid\`
        [ \$? = 0 ] && echo "OK" || echo "FAIL"
        rm -f /var/run/zest.pid
        ;;
  restart|reload)
        "\$0" stop
        "\$0" start
        ;;
  *)
        echo "Usage: \$0 {start|stop|restart}"
        exit 1
esac
EOF
  chmod 755 $TARGET/usr/bin/zestboot
  ln -s ../../usr/bin/zestboot $TARGET/etc/init.d/S99zest
fi

if test ! -d $TARGET/usr/share/fonts ; then
    mkdir -p $TARGET/usr/share/fonts
    cp -a $SRCDIR/setup/extra/fonts/* $TARGET/usr/share/fonts
fi

if test ! -f $TARGET/etc/init.d/S01zestoverlay ; then
    cat <<EOF > $TARGET/etc/init.d/S01zestoverlay
#!/bin/sh
case "\$1" in
  start)
        printf "Configuring the zeST overlay filesystem: "
        if [ ! -f /sdcard/overlay.bin ] ; then
            /bin/dd of=/sdcard/overlay.bin bs=1M seek=2 count=0
            /sbin/mke2fs -F /sdcard/overlay.bin
            chmod -w /sdcard/overlay.bin
        fi
        mkdir -p /var/overlay
        mount -oloop,sync -text2 /sdcard/overlay.bin /var/overlay
        mkdir -p /var/overlay/work /var/overlay/etc
        mount -t overlay overlay -olowerdir=/etc,upperdir=/var/overlay/etc,workdir=/var/overlay/work /etc
        [ \$? = 0 ] && echo "OK" || echo "FAIL"
        ;;
  stop)
        printf "Deactivating the zeST overlay filesystem: "
        umount /etc
        umount /var/overlay
        ;;
  restart|reload)
        ;;
  *)
        echo "Usage: \$0 {start|stop|restart}"
        exit 1
esac
EOF
    chmod +x $TARGET/etc/init.d/S01zestoverlay
fi

mkdir -p $TARGET/etc/bluetooth/var
ln -s /etc/bluetooth/var $TARGET/var/lib/bluetooth
cat <<EOF > $TARGET/etc/bluetooth/main.conf
[General]
Name = zeST

[Policy]
AutoEnable=true
EOF

cp -a $SRCDIR/linux/zeST $TARGET/usr/bin
