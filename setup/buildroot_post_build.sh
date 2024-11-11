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

if test ! -f $TARGET/usr/bin/zestinit.sh ; then
    cat <<EOF > $TARGET/usr/bin/zestinit.sh
#/bin/sh
mount -t proc proc /proc
mount -tvfat -oflush,dirsync,noatime,noexec,nodev,fmask=0133,dmask=0022 /dev/mmcblk0p1 /sdcard
if [ ! -f /sdcard/overlay.bin ] ; then
    dd if=/dev/zero of=/sdcard/overlay.bin bs=1m count=1
    /sbin/mke2fs -F /sdcard/overlay.bin
    chmod -w /sdcard/overlay.bin
fi
mkdir -p /var/overlay
mount -oloop,sync -text2 /sdcard/overlay.bin /var/overlay
mkdir -p /var/overlay/work /var/overlay/etc
mount -t overlay overlay -olowerdir=/etc,upperdir=/var/overlay/etc,workdir=/var/overlay/work /etc
exec /sbin/init $*
EOF
    chmod +x $TARGET/usr/bin/zestinit.sh
fi

if test ! -d $TARGET/var/overlay ; then
    mkdir -p $TARGET/var/overlay
    echo "/sdcard/overlay.bin /var/overlay ext2 loop,sync,noatime 0 2" >> $TARGET/etc/fstab
    echo "overlay /etc overlay lowerdir=/etc,upperdir=/var/overlay/etc,workdir=/var/overlay/work 0 2" >> $TARGET/etc/fstab
fi

mkdir -p $TARGET/etc/bluetooth/var
ln -s /etc/bluetooth/var $TARGET/var/lib/bluetooth
cat <<EOF > $TARGET/etc/bluetooth/main.conf
[General]

Name = zeST
EOF

cp $SRCDIR/linux/zeST $TARGET/usr/bin
