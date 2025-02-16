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
  ln -s ../../usr/bin/zestboot $TARGET/etc/init.d/S30zest
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
        mkdir -p /overlay
        mount -oloop,sync -text2 /sdcard/overlay.bin /overlay
        mkdir -p /overlay/work1 /overlay/work2 /overlay/work3 /overlay/etc /overlay/var /overlay/root
        mount -t overlay overlay -olowerdir=/etc,upperdir=/overlay/etc,workdir=/overlay/work1 /etc
        mount -t overlay overlay -olowerdir=/var,upperdir=/overlay/var,workdir=/overlay/work2 /var
        mount -t overlay overlay -olowerdir=/root,upperdir=/overlay/root,workdir=/overlay/work3 /root
        [ \$? = 0 ] && echo "OK" || echo "FAIL"
        ;;
  stop)
        printf "Deactivating the zeST overlay filesystem: "
        umount /root
        umount /var
        umount /etc
        umount /overlay
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

# bluetooth setup
#mkdir -p $TARGET/etc/bluetooth/var
#ln -sf /etc/bluetooth/var $TARGET/var/lib/bluetooth
cat <<EOF > $TARGET/etc/bluetooth/main.conf
[General]
Name = zeST

[Policy]
AutoEnable=true
EOF

# zeST binary
cp -a $SRCDIR/linux/zeST $TARGET/usr/bin

# default ROM image
mkdir -p $TARGET/usr/share/zest
cp -a $SRCDIR/setup/output/src/rom.img $TARGET/usr/share/zest
