#nmcli connection modify direct-connection ipv4.route-metric 100
#nmcli connection modify lan-connection ipv4.route-metric 200
#nmcli connection modify wifi-connection ipv4.route-metric 300

#changed to:

nmcli connection modify direct-connection ipv4.route-metric 100
nmcli connection modify lan-connection ipv4.route-metric 200
#nmcli connection modify wifi-connection ipv4.route-metric 300


## AS FAR AS I CAN TELL 5/28/24 the route metric was not modified by anything I did.  