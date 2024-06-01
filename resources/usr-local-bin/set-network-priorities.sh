#!/bin/bash -e

# Setting Network Priorities for FabMo
nmcli connection modify direct-connection ipv4.route-metric 100
nmcli connection modify lan-connection ipv4.route-metric 200
nmcli connection modify wifi-connection ipv4.route-metric 300
