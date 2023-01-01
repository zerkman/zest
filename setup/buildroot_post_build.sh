#!/bin/sh

TARGET=output/target
SRCDIR=`dirname $0`/..

if test ! -d $TARGET/boot ; then
  mkdir $TARGET/boot
  echo "/dev/mmcblk0p1 /boot vfat flush,dirsync,noatime,noexec,nodev 0 0" >> $TARGET/etc/fstab
fi

if test ! -f $TARGET/root/zestboot ; then
cat <<EOF > $TARGET/root/zestboot
#!/bin/sh
case "\$1" in
  start)
        printf "Starting zeST: "
        /usr/sbin/zeST /boot/rom.img &
        echo \$! > /var/run/zest.pid
        [ \$? = 0 ] && echo "OK" || echo "FAIL"
        ;;
  stop)
        printf "Stopping zeST: "
        /bin/kill \`/bin/cat /var/run/zest.pid\`
        [ \$? = 0 ] && echo "OK" || echo "FAIL"
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
  chmod 755 $TARGET/root/zestboot
  ln -s ../../root/zestboot $TARGET/etc/init.d/S99zest
fi

cp $SRCDIR/linux/zeST $TARGET/usr/sbin
