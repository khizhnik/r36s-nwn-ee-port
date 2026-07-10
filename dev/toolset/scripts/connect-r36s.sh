#!/bin/bash
set +e

R36S_IP="${R36S_IP:-192.168.7.2}"
HOST_IP="${HOST_IP:-192.168.7.1}"
R36S_USER="${R36S_USER:-ark}"
R36S_PASS="${R36S_PASS:-ark}"

echo "=== R36S USB SSH CONNECT ==="

need() {
  command -v "$1" >/dev/null 2>&1
}

log() {
  echo "$*"
}

list_usb_candidates() {
  ip -o link show 2>/dev/null | awk -F': ' '
    {
      name = $2
      sub(/@.*/, "", name)
      if (name ~ /^(usb|enx)/) {
        print name
      }
    }
  ' | sort -u
}

is_usb_net_iface() {
  local iface="$1"
  local sys="/sys/class/net/$iface"
  local props

  [ -e "$sys" ] || return 1

  need udevadm || return 1

  props="$(udevadm info -q property -p "$sys" 2>/dev/null)"
  [ -n "$props" ] || return 1

  printf '%s\n' "$props" | grep -Eq '^(ID_BUS=usb|ID_NET_DRIVER=rndis_host|ID_NET_DRIVER=cdc_subset|ID_NET_DRIVER=cdc_ether)$'
}

find_existing_iface() {
  local iface

  for iface in $(list_usb_candidates); do
    if is_usb_net_iface "$iface"; then
      echo "$iface"
      return 0
    fi
  done

  return 1
}

find_iface() {
  local iface

  iface="$(find_existing_iface)"
  if [ -n "$iface" ]; then
    echo "$iface"
    return 0
  fi

  for i in $(seq 1 30); do
    for iface in $(list_usb_candidates); do
      if is_usb_net_iface "$iface"; then
        echo "$iface"
        return 0
      fi
    done
    sleep 1
  done

  return 1
}

set_nm_unmanaged() {
  local iface="$1"

  if need nmcli; then
    sudo nmcli dev set "$iface" managed no
  fi
}

IFACE="$(find_iface)"

if [ -z "$IFACE" ]; then
  echo "R36S USB network interface not found."
  echo
  echo "Check:"
  echo "- R36S is powered on"
  echo "- USB cable supports data"
  echo "- R36S golden DTB is installed"
  echo "- PortMaster USB Net script has been run or autostart is configured"
  exit 1
fi

echo "Found interface: $IFACE"

echo "Configuring host side: $HOST_IP/24 on $IFACE"

sudo ip link set "$IFACE" up
set_nm_unmanaged "$IFACE"
sudo ip route del default dev "$IFACE" 2>/dev/null || true
sudo ip addr flush dev "$IFACE"
sudo ip -6 addr flush dev "$IFACE"
sudo ip addr add "$HOST_IP/24" dev "$IFACE"
sudo ip route replace "$R36S_IP/24" dev "$IFACE" src "$HOST_IP"

echo "Waiting for $R36S_IP..."

OK=0
for i in $(seq 1 20); do
  if ping -c1 -W1 "$R36S_IP" >/dev/null 2>&1; then
    OK=1
    break
  fi
  sleep 1
done

if [ "$OK" != "1" ]; then
  echo "R36S did not answer ping."
  echo
  echo "Debug:"
  ip addr show "$IFACE"
  ip neigh show dev "$IFACE"
  exit 2
fi

echo "R36S is reachable."

if need sshpass; then
  echo "Connecting with sshpass..."
  exec sshpass -p "$R36S_PASS" ssh \
    -o StrictHostKeyChecking=accept-new \
    "$R36S_USER@$R36S_IP"
else
  echo
  echo "sshpass is not installed."
  echo "Connect manually:"
  echo
  echo "ssh $R36S_USER@$R36S_IP"
  echo
  exec ssh "$R36S_USER@$R36S_IP"
fi
