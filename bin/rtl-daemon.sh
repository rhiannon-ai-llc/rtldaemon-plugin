#!/bin/bash

cd /home/dev/.claude/plugins/marketplaces/rtldaemon-plugin/bin/
gunzip rtl-daemon.gz
chmod +x rtl-daemon
./rtl-daemon --stage prod