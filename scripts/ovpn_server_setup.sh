#!/usr/bin/env bash
# Starts a real OpenVPN server on the CI runner and writes a client profile (everything inline) that
# points at 10.0.2.2 (the host as seen from the Android emulator).
set -e
D=/tmp/ovpn
rm -rf "$D"; mkdir -p "$D"; cd "$D"
[ -c /dev/net/tun ] || { sudo mkdir -p /dev/net; sudo mknod /dev/net/tun c 10 200; sudo chmod 666 /dev/net/tun; }
openssl req -x509 -newkey rsa:2048 -nodes -keyout ca.key -out ca.crt -subj "/CN=ci-ca" -days 3 2>/dev/null
for n in server client; do openssl req -newkey rsa:2048 -nodes -keyout $n.key -out $n.csr -subj "/CN=$n" 2>/dev/null; done
printf 'basicConstraints=CA:FALSE\nextendedKeyUsage=serverAuth\nkeyUsage=digitalSignature,keyEncipherment\n' > ext_server.cnf
printf 'basicConstraints=CA:FALSE\nextendedKeyUsage=clientAuth\nkeyUsage=digitalSignature\n' > ext_client.cnf
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 3 -extfile ext_server.cnf 2>/dev/null
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days 3 -extfile ext_client.cnf 2>/dev/null
cat > server.conf <<CONF
port 1194
proto udp
dev tun
ca $D/ca.crt
cert $D/server.crt
key $D/server.key
dh none
server 10.8.0.0 255.255.255.0
topology subnet
keepalive 10 60
data-ciphers AES-256-GCM
verb 3
log $D/server.log
CONF
sudo openvpn --config server.conf --daemon
sleep 5
ip -o addr show | grep -E "tun[0-9]" || { echo "no tun interface: server failed"; tail -20 "$D/server.log"; exit 1; }
cat > client.ovpn <<CONF
client
dev tun
proto udp
remote 10.0.2.2 1194
nobind
persist-key
remote-cert-tls server
data-ciphers AES-256-GCM
verb 3
<ca>
$(cat ca.crt)
</ca>
<cert>
$(openssl x509 -in client.crt)
</cert>
<key>
$(cat client.key)
</key>
CONF
echo "openvpn server is up; client profile: $D/client.ovpn ($(wc -c < client.ovpn) bytes)"
