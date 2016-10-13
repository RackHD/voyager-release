#!/usr/bin/env python

import ssl
import atexit
import sys
from pyVim.connect import SmartConnect, Disconnect
from pyVmomi import vim
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

    vm = au.get_obj(content, [vim.VirtualMachine], args.vm_name)
    ip_address = au.get_ip_for_vm_network(vm, args.port_group_name)
    return ip_address
 

if __name__ == "__main__":
    sys.exit(main())
