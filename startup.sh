#!/bin/sh

INTERFACE="wg0"
WAN_INTERFACE="eth0"
VPN_NET="10.0.0.0/24"
VPN_IP="10.0.0.1/24"
VPN_PEER_IP="10.0.0.2"


term_handler() {
    echo "Stopping..."

    iptables -D FORWARD -i $INTERFACE -j ACCEPT 2>/dev/null
    iptables -D FORWARD -o $INTERFACE -j ACCEPT 2>/dev/null
    iptables -t nat -D POSTROUTING -s $VPN_NET -o $WAN_INTERFACE -j MASQUERADE 2>/dev/null

    kill -SIGTERM "$vp_pid" 2>/dev/null
    wait "$vp_pid"
    exit 0
}
trap term_handler SIGTERM SIGINT

echo "Creating interface..."

amneziawg-go -f $INTERFACE &
vp_pid=$!

tries=0
while ! ip link show $INTERFACE > /dev/null 2>&1 && [ $tries -lt 20 ]; do
    sleep 0.5
    tries=$((tries + 1))
done

if [ $tries -ge 20 ]; then
    echo "Error: Interface $INTERFACE create timeout. Exiting..."
    kill $vp_pid 2>/dev/null
    exit 1
fi

echo "Ok."

echo "Applying configuration..."

config_tries=0
while ! wg setconf $INTERFACE /etc/amnezia/wg0.conf 2>/dev/null; do
    if [ $config_tries -ge 10 ]; then
        echo "Error: Failed to apply configuration. Exiting..."
        kill "$vp_pid" 2>/dev/null
        exit 1
    fi
    echo "Waiting for socket..."
    sleep 1
    config_tries=$((config_tries + 1))
done

echo "Ok."

echo "Applying ip, mtu, rules (PostUp)..."

ip addr add $VPN_IP dev $INTERFACE
ip link set dev $INTERFACE mtu 1280
ip link set up dev $INTERFACE

iptables -I FORWARD 1 -i $INTERFACE -j ACCEPT
iptables -I FORWARD 1 -o $INTERFACE -j ACCEPT

iptables -t nat -I POSTROUTING 1 -s $VPN_NET -o $WAN_INTERFACE -j MASQUERADE

echo "Ok."

echo "Applying iptables..."


#copypaste
#iptables -t nat -A PREROUTING -i $WAN_INTERFACE -p tcp --dport <YOUR_PORT> -j DNAT --to-destination $VPN_PEER_IP:<YOUR_PORT>
#iptables -A FORWARD -i $WAN_INTERFACE -o $INTERFACE -p tcp --dport <YOUR_PORT> -d $VPN_PEER_IP -j ACCEPT

#port 25570
iptables -t nat -A PREROUTING -i $WAN_INTERFACE -p tcp --dport 25570 -j DNAT --to-destination $VPN_PEER_IP:25570
iptables -A FORWARD -i $WAN_INTERFACE -o $INTERFACE -p tcp --dport 25570 -d $VPN_PEER_IP -j ACCEPT

#port 25571
iptables -t nat -A PREROUTING -i $WAN_INTERFACE -p tcp --dport 25571 -j DNAT --to-destination $VPN_PEER_IP:25571
iptables -A FORWARD -i $WAN_INTERFACE -o $INTERFACE -p tcp --dport 25571 -d $VPN_PEER_IP -j ACCEPT

#ssh
iptables -t nat -A PREROUTING -i $WAN_INTERFACE -p tcp --dport 222 -j DNAT --to-destination $VPN_PEER_IP:222
iptables -A FORWARD -i $WAN_INTERFACE -o $INTERFACE -p tcp --dport 222 -d $VPN_PEER_IP -j ACCEPT

#established
iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT

echo "Ok."

echo "Awg ready. Running..."

wait "$vp_pid"