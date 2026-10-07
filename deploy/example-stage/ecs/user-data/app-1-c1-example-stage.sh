#!/bin/bash
set -euo pipefail

timezone=Asia/Jakarta
timedatectl set-timezone "$timezone"

echo "Example stage application server" > /etc/motd
