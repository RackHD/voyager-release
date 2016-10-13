#!/usr/bin/env python

from __future__ import print_function
from pyVim.connect import SmartConnect, Disconnect
from pyVmomi import vim
import atexit
import sys
from argparse import ArgumentParser
import ssl
import nmap
import os
import acceptance_utils as au

def main():
    args = au.get_args()

    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    # connect this thing
    service_instance = SmartConnect(
        host=args.host,
        user=args.user,
        pwd=args.password,
        port=args.port,
        sslContext=ctx)
    # disconnect this thing
    atexit.register(Disconnect, service_instance)

    # get content
    content = service_instance.RetrieveContent()

    # create the test_vswitch and the port groups
    rhd_vswitch = args.test_id + "-RHD-to-Nodes"
    rhd_vswitch_pg = args.test_id + "-RHD-to-Nodes-PG"

    vm = au.get_obj(content, [vim.VirtualMachine], args.vm_name)
    if vm:
        au.Destroy_vm(vm)

    if args.delete_network:
        port_group = au.get_obj(content, [vim.Network], rhd_vswitch_pg)
        if port_group:
            for host in port_group.host:
                print(host)
                au.DelHostPortgroup(host, rhd_vswitch_pg)

        vswitch = au.get_obj(content, [vim.Network], rhd_vswitch)
        if vswitch:
            for host in port_group.host:
                print(host)
                au.DelHostSwitch(host, rhd_vswitch)

# Main section
if __name__ == "__main__":
    sys.exit(main())
