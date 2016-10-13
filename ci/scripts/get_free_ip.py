import os
import sys
import nmap


class FreeIP:
    ip = ""
    # subnetMask = "255.255.255.0"
    # gateway = "10.240.20.1"
    # dnsServerList = ["10.240.16.11", "10.253.130.61"]


def GetFreeIP(subnet, low, high):
    nm = nmap.PortScanner()
    nm.scan(hosts=subnet, arguments='-v -sn -n')
    freeIP = FreeIP()
    for x in nm.all_hosts():
        lastOctet = int(x.split(".")[3])
        if nm[x]['status']['state'] == "down" and (lastOctet <= high and lastOctet >= low):
            freeIP.ip = x
    return freeIP


def main():
    # Find a free IP for the public interface
    ipAddress = GetFreeIP("10.240.20.0/24", 100, 150)
    os.putenv("AVAILABLE_IP_ADDRESS",
              "Hello friend, you succeeded " + ipAddress.ip)
    return ipAddress.ip

if __name__ == "__main__":
    # availableIP = main()
    sys.exit(main())
