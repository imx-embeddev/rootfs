#!/bin/sh

cd /firmware/modules

case "$1" in
  start)
        echo "load driver modules ..."
        insmod sdriver_revision.ko
        ;;
  stop)
        echo "unload driver modules ..."
        rmmod sdriver_revision.ko
        ;;
  restart|reload)
        "$0" stop
        "$0" start
        ;;
  *)
        echo "Usage: $0 {start|stop|restart}"
        exit 1
esac

exit $?