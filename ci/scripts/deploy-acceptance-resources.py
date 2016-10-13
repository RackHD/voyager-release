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

    # create the test_vswitch and the port groups
    rhd_vswitch = args.test_id + "-RHD-to-Nodes"
    rhd_vswitch_pg = args.test_id + "-RHD-to-Nodes-PG"
    nic_label = "Network adapter 2"
    vm = au.get_obj(content, [vim.VirtualMachine], args.vm_name)
    host_running_vm = vm.runtime.host
    au.CreateVSwitchForHost(host_running_vm, rhd_vswitch)
    au.CreatePortGroupForHost(
        host_running_vm, rhd_vswitch, rhd_vswitch_pg, 4094)
    au.UpdateNetworkInterfaceInVM(content, vm, nic_label, rhd_vswitch_pg, False)

if __name__ == "__main__":
    sys.exit(main())
