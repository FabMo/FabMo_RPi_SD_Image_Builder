This directory contains subdirectories. Each subdirectory contains files
These files can be copied to the correct locations, then a set of daemons
can be restarted. The result is to change the networking configuration
model of the raspberry pi.  

The daemons that have to be restarted are listed in "restart.list"

The modes that are currently available are named and described below
 * asks_for_ip_address

        This mode is often the simplest if the tool needs 
        to be plugged into an existing network, and accept the network's
        configuration.

        In this mode, the raspberry pi is a dhcp client. It attempts
        to obtain an ip address when the eth0 interface is activated, 
        by requesting an ip address from any available dhcp server.

        This mode makes sense if you are attaching the tool to an 
        existing network that hands out ip addresses dynamically.

        Most home networks work this way. For the standard use case the
        router or server assigns the ip address and the user can look at the 
        LCD screen to discover the current ip address, 
        or look at the wifi Access Point SSID, 
        or use a usb thumb with the "magic file" of network.txt on it.
        The server can be configured to always give the same address though
        the address is usally stable enough that it is not necessary.

        In this mode, if the dhcp request goes unanswered (maybe there
        is no dhcp server on the network?), then the eth0 interface
        will default to 192.168.44.1
        
        In this mode, the wifi is set up to be an access point and will
        act as a dhcp server, giving out addresses in the range of 
        192.168.42.100 - 192.168.42.200, and will be addressable with 
        the static address fo 192.168.42.1

        If the raspberry pi fails to get an address and defaults to 
        192.168.44.1, and there is an ethernet cable between the tool
        and a personal computer, it is likely that the personal computer
        needs to be configured. (How to do this will differ depending 
        on the OS). The desired configuration is that the computer be 
        configured with a static ip address such as 192.168.44.2 and 
        a netmask for 255.255.255.0  (any ip on 192.168.44.0/24 other 
        than the tool ip of 192.168.44.1 will work)

 * assigns_ip_addresses

        In this mode, the raspberry pi acts as a dhcp server on the 
        eth0 interface. If an ethernet is attached to eth0 and a 
        device - laptop or otherwise puts out a request for an IP
        Address, the raspberry pi will offer one with a 24 hour lease.

        This is the most common configuration for personal computers. 
        By default, they are usually set to make an request for an 
        address using dhcp. In this mode, you can generally put an 
        ethernet cable between a computer and the tool, and then 
        connect to that tool at 192.168.44.1.

        This is the simplest mode for a direct connection.

 * configured_static_ip
        Not yet implemented
        Check with your local network manager.