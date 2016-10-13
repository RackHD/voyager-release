from __future__ import print_function
from argparse import ArgumentParser
from pyVmomi import vim
import re


def get_args():
    """
    Get CLI arguments.
    """
    parser = ArgumentParser(description='Arguments for talking to vCenter')

    parser.add_argument('-s', '--host',
                        required=True,
                        action='store',
                        help='vSphere service to connect to.')

    parser.add_argument('-o', '--port',
                        type=int,
                        default=443,
                        action='store',
                        help='Port to connect on.')

    parser.add_argument('-u', '--user',
                        required=True,
                        action='store',
                        help='Username to use.')

    parser.add_argument('-p', '--password',
                        required=False,
                        action='store',
                        help='Password to use.')

    parser.add_argument('--datacenter_name',
                        required=False,
                        action='store',
                        default=None,
                        help='Name of the Datacenter you\
                          wish to use. If omitted, the first\
                          datacenter will be used.')

    parser.add_argument('--datastore_name',
                        required=False,
                        action='store',
                        default=None,
                        help='Datastore you wish the VM to be deployed to. \
                          If left blank, VM will be put on the first \
                          datastore found.')

    parser.add_argument('--cluster_name',
                        required=False,
                        action='store',
                        default=None,
                        help='Name of the cluster you wish the VM to\
                          end up on. If left blank the first cluster found\
                          will be used')

    parser.add_argument('--host_name',
                        required=False,
                        action='store',
                        default=None,
                        help='Name of the host you wish the VM to\
                          end up on. If left blank the first cluster found\
                          will be used')

    parser.add_argument('--vm_name',
                        required=True,
                        action='store',
                        default=None,
                        help='Name of the vm you wish the configure')

    parser.add_argument('--vswitch_name',
                        required=False,
                        action='store',
                        default=None,
                        help='Name of the vswitch to use')

    parser.add_argument('--port_group_name',
                        required=False,
                        action='store',
                        default=None,
                        help='Name of the port group to use')

    parser.add_argument('-t', '--test_id',
                        required=True,
                        action='store',
                        default=None,
                        help='Test ID.')

    parser.add_argument('--tearDown',
                        dest='tearDown',
                        required=False,
                        action='store_false',
                        help='Tears down an existing environment instead\
                          of building.')

    parser.add_argument('--delete_network',
                        required=False,
                        action='store',
                        default=False,
                        help='Whether or not to delete networks.')

    args = parser.parse_args()

    if not args.password:
        args.password = getpass(prompt='Enter password: ')

    return args


def get_host_vswitch(host, name):
    for vswitch in host.config.network.vswitch:
        if vswitch.name == name:
            return vswitch
    return None


def get_obj(content, vimtype, name):
    """
    Return an object by name, if name is None the
    first found object is returned
    """
    obj = None
    container = content.viewManager.CreateContainerView(
        content.rootFolder, vimtype, True)
    for c in container.view:
        if name:
            if c.name == name:
                obj = c
                break
        else:
            obj = c
            break

    return obj


def exists(content, vimtype, name):
    return get_obj(content, vimtype, name) != None


def get_obj_in_list(obj_name, obj_list):
    """
    Gets an object out of a list (obj_list) whos name matches obj_name.
    """
    for o in obj_list:
        if o.name == obj_name:
            return o
    print ("Unable to find object by the name of %s in list:\n%s" %
           (obj_name, map(lambda o: o.name, obj_list)))
    exit(1)


def get_objects(si, args):
    """
    Return a dict containing the necessary objects for deployment.
    """
    # Get datacenter object.
    datacenter_list = si.content.rootFolder.childEntity
    if args.datacenter_name:
        datacenter_obj = get_obj_in_list(args.datacenter_name, datacenter_list)
    else:
        datacenter_obj = datacenter_list[0]

    # Get cluster object.
    cluster_list = datacenter_obj.hostFolder.childEntity
    if args.cluster_name:
        cluster_obj = get_obj_in_list(args.cluster_name, cluster_list)
    elif len(cluster_list) > 0:
        cluster_obj = cluster_list[0]
    else:
        print ("No clusters found in DC (%s)." % datacenter_obj.name)
        cluster_obj = None

    # Get host object.
    host_list = cluster_obj.host
    if args.host_name:
        # host_obj = get_obj_in_list(args.host_name, host_list)
        host_obj = get_esx_host_with_ip(si, args.host_name)
    elif len(cluster_list) > 0:
        host_obj = host_list[0]
    else:
        print ("No host found in Cluster (%s)." % cluster_obj.name)
        host_obj = None

    # Get datastore object.
    datastore_list = datacenter_obj.datastoreFolder.childEntity
    if args.datastore_name:
        datastore_obj = get_obj_in_list(args.datastore_name, datastore_list)
    elif len(host_obj.datastore) > 0:
        datastore_obj = host_obj.datastore[0]
    elif len(datastore_list) > 0:
        datastore_obj = datastore_list[0]
    else:
        print ("No datastores found in DC (%s)." % datacenter_obj.name)
        datastore_obj = None

    return {"datacenter": datacenter_obj,
            "datastore": datastore_obj,
            "host": host_obj}


def CreateDVSwitchForHosts(hosts, dVswitchName, network_folder):
    dvs_host_configs = []
    uplink_port_names = []
    dvs_create_spec = vim.DistributedVirtualSwitch.CreateSpec()
    dvs_config_spec = vim.DistributedVirtualSwitch.ConfigSpec()
    dvs_config_spec.name = dVswitchName
    dvs_config_spec.uplinkPortPolicy = vim.DistributedVirtualSwitch.NameArrayUplinkPortPolicy()
    dvs_config_spec.maxPorts = 2000

    for index, host in enumerate(hosts):
        uplink_port_names.append("dvUplink%d" % index)
        pnic_spec = vim.dvs.HostMember.PnicSpec()
        pnic_spec.pnicDevice = 'vmnic1'
        dvs_host_config = vim.dvs.HostMember.ConfigSpec()
        dvs_host_config.operation = vim.ConfigSpecOperation.add
        dvs_host_config.host = host
        dvs_host_config.backing = vim.dvs.HostMember.PnicBacking()
        dvs_host_config.backing.pnicSpec = [pnic_spec]
        dvs_host_configs.append(dvs_host_config)

    dvs_config_spec.uplinkPortPolicy.uplinkPortName = uplink_port_names
    dvs_config_spec.host = dvs_host_configs

    dvs_create_spec.configSpec = dvs_config_spec
    dvs_create_spec.productInfo = vim.dvs.ProductSpec(version='6.0.0')

    task = network_folder.CreateDVS_Task(dvs_create_spec)
    wait_for_task(task)


def CreateVSwitchForHost(host, vswitchName):
    vswitch_spec = vim.host.VirtualSwitch.Specification()
    vswitch_spec.numPorts = 1024
    vswitch_spec.mtu = 1450
    host.configManager.networkSystem.AddVirtualSwitch(vswitchName,
                                                      vswitch_spec)


def CreatePortGroupForHost(host, vswitchName, portgroupName, vlanId):
    portgroup_spec = vim.host.PortGroup.Specification()
    portgroup_spec.vswitchName = vswitchName
    portgroup_spec.name = portgroupName
    portgroup_spec.vlanId = int(vlanId)
    network_policy = vim.host.NetworkPolicy()
    network_policy.security = vim.host.NetworkPolicy.SecurityPolicy()
    network_policy.security.allowPromiscuous = True
    network_policy.security.macChanges = True
    network_policy.security.forgedTransmits = True
    portgroup_spec.policy = network_policy

    host.configManager.networkSystem.AddPortGroup(portgroup_spec)


def CreatePortGroupForDSwitch(dv_switch, portgroupName, vlanId):
    dv_pg_spec = vim.dvs.DistributedVirtualPortgroup.ConfigSpec()
    dv_pg_spec.name = portgroupName
    dv_pg_spec.numPorts = 32
    dv_pg_spec.type = vim.dvs.DistributedVirtualPortgroup.PortgroupType.earlyBinding
    dv_pg_spec.defaultPortConfig = vim.dvs.VmwareDistributedVirtualSwitch.VmwarePortConfigPolicy()

    vlan_config = vim.dvs.VmwareDistributedVirtualSwitch.VlanIdSpec()
    vlan_config.vlanId = int(vlanId)
    vlan_config.inherited = False
    dv_pg_spec.defaultPortConfig.vlan = vlan_config

    network_policy = vim.dvs.VmwareDistributedVirtualSwitch.SecurityPolicy()
    network_policy.allowPromiscuous = vim.BoolPolicy(value=True)
    network_policy.forgedTransmits = vim.BoolPolicy(value=True)
    network_policy.macChanges = vim.BoolPolicy(value=True)
    network_policy.inherited = False
    dv_pg_spec.defaultPortConfig.securityPolicy = network_policy

    task = dv_switch.AddDVPortgroup_Task([dv_pg_spec])
    wait_for_task(task)


def DelHostSwitch(host, vswitchName):
    host.configManager.networkSystem.RemoveVirtualSwitch(vswitchName)


def DelHostPortgroup(host, portgroupName):
    host.configManager.networkSystem.RemovePortGroup(portgroupName)


def UpdateNetworkInterfaceInVM(content, vm, nic_label, portgroupName, distributed):
    virtual_nic_device = findVMNic(vm, nic_label)
    virtual_nic_spec = createEditSpecForNic(virtual_nic_device)
    if distributed:
        setPortDistributedGroupInNicSpec(content, virtual_nic_spec, portgroupName)
    else:
        setProtGroupInNicSpec(content, virtual_nic_spec, portgroupName)
    setConnectionSettingInNicSpec(virtual_nic_spec)
    spec = vim.vm.ConfigSpec()
    spec.deviceChange = [virtual_nic_spec]
    task = vm.ReconfigVM_Task(spec=spec)
    wait_for_task(task)


def findVMNic(vm, nic_label):
    for dev in vm.config.hardware.device:
        if isinstance(dev, vim.vm.device.VirtualEthernetCard) and dev.deviceInfo.label == nic_label:
            virtual_nic_device = dev

    if not virtual_nic_device:
        raise RuntimeError('Virtual {} could not be found.'.format(nic_label))
    else:
        return virtual_nic_device


def get_ip_for_vm_network(vm, network):
    ip = None
    for net in vm.guest.net:
        if net.network == network:
            while len(net.ipAddress) < 2:
                pass
            ip_regex = re.compile('^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$')
            ipv4 = filter(ip_regex.match, net.ipAddress)
            ip = ipv4[0]
            break
    return ip


def Destroy_vm(vm):
    if format(vm.runtime.powerState) == "poweredOn":
        task = vm.PowerOffVM_Task()
        wait_for_task(task)
    task = vm.Destroy_Task()
    wait_for_task(task)


def Reboot_vm_and_wait_for_ip(vm):
    task = vm.ResetVM_Task()
    wait_for_task(task)
    wait_for_vmtools(vm)
    wait_for_vmTools_ip(vm)


def createEditSpecForNic(virtual_nic_device):
    virtual_nic_spec = vim.vm.device.VirtualDeviceSpec()
    virtual_nic_spec.operation = vim.vm.device.VirtualDeviceSpec.Operation.edit
    virtual_nic_spec.device = virtual_nic_device
    return virtual_nic_spec


def setProtGroupInNicSpec(content, virtual_nic_spec, portgroupName):
    virtual_nic_spec.device.backing = vim.vm.device.VirtualEthernetCard.NetworkBackingInfo()
    virtual_nic_spec.device.backing.useAutoDetect = False
    virtual_nic_spec.device.backing.network = get_obj(
        content, [vim.Network], portgroupName)
    virtual_nic_spec.device.backing.deviceName = portgroupName


def setPortDistributedGroupInNicSpec(content, virtual_nic_spec, portgroupName):
    virtual_nic_spec.device.backing = vim.vm.device.VirtualEthernetCard.DistributedVirtualPortBackingInfo()
    port_group = get_obj(
        content, [vim.dvs.DistributedVirtualPortgroup], portgroupName)
    virtual_nic_spec.device.backing.port = vim.dvs.PortConnection()
    virtual_nic_spec.device.backing.port.portgroupKey = port_group.key
    virtual_nic_spec.device.backing.port.switchUuid = port_group.config.distributedVirtualSwitch.uuid
    port_key = find_available_portkey(
        port_group.config.distributedVirtualSwitch, port_group.key)
    virtual_nic_spec.device.backing.port.portKey = port_key.key


def find_available_portkey(dvs, portgroupkey):
    search_portkey = []
    criteria = vim.dvs.PortCriteria()
    criteria.connected = False
    criteria.inside = True
    criteria.portgroupKey = portgroupkey
    ports = dvs.FetchDVPorts(criteria)
    if len(ports) == 0:
        raise Exception("no more available port id for distributed port group")
    return ports[0]


def setConnectionSettingInNicSpec(virtual_nic_spec):
    virtual_nic_spec.device.connectable = vim.vm.device.VirtualDevice.ConnectInfo()
    virtual_nic_spec.device.connectable.startConnected = True
    virtual_nic_spec.device.connectable.allowGuestControl = True
    virtual_nic_spec.device.connectable.connected = True


def wait_for_task(task):
    """ wait for a vCenter task to finish """
    task_done = False
    while not task_done:
        if task.info.state == 'running':
            pass

        if task.info.state == 'success':
            return task.info.result

        if task.info.state == 'error':
            print ("there was an error")
            task_done = True


def wait_for_vmtools(vm):
    tools_status = vm.guest.toolsStatus

    # Wait for clone to be totally up and vmware tools is running
    while (tools_status == 'toolsNotInstalled' or tools_status == 'toolsNotRunning'):
        tools_status = vm.guest.toolsStatus


def wait_for_vmTools_ip(vm):
    while vm.guest.ipAddress == None:
        pass


def wait_for_wmtools(vm):
    # Wait for clone to be totally up and vmware tools is running
    tools_status = vm.guest.toolsStatus
    while (tools_status == 'toolsNotInstalled' or tools_status == 'toolsNotRunning'):
        tools_status = vm.guest.toolsStatus


def configure_vm_interfaces(si, vm, ipAddress):
    # Configure Network
    # TODO: Need to enable admin account
    interfaceName = "Local Area Network"
    cmd = "C:\\Windows\\System32\\netsh.exe"
    arguments = "interface ip set address \"%s\" static %s %s %s" % (
        interfaceName, ipAddress.ip, ipAddress.subnetMask, ipAddress.gateway)
    run_command_in_vm(si, vm, "Administrator", "voyager", cmd, arguments)


def run_command_in_vm(si, vm, user, password, cmd, arguments):
    wait_for_wmtools(vm)

    creds = vim.vm.guest.NamePasswordAuthentication(
        username=user, password=password
    )

    try:
        pm = si.RetrieveContent().guestOperationsManager.processManager

        ps = vim.vm.guest.ProcessManager.ProgramSpec(
            programPath=cmd,
            arguments=arguments
        )
        pid = pm.StartProgramInGuest(vm, creds, ps)

        if pid > 0:
            print ("Program executed, PID is %d" % pid)
        process = pm.ListProcessesInGuest(vm, creds, [pid])[0]
        while process.exitCode is None:
            process = pm.ListProcessesInGuest(vm, creds, [pid])[0]
        print ("Program %s exited with code %d" % (pid, process.exitCode))

    except IOError, e:
        print (e)

# def clone_vm(
#         content, template, vm_name, si,
#         datacenter_name, datastore_name,
#         cluster_name, ipAddress):
#     """
#     Clone a VM from a template/VM, datacenter_name, vm_folder, datastore_name
#     cluster_name, resource_pool, and power_on are all optional.
#     """
#
#     # if none git the first one
#     datacenter = get_obj(content, [vim.Datacenter], datacenter_name)
#
#     destfolder = datacenter.vmFolder
#
#     if datastore_name:
#         datastore = get_obj(content, [vim.Datastore], datastore_name)
#     else:
#         datastore = get_obj(
#             content, [vim.Datastore], template.datastore[0].info.name)
#
#     # if None, get the first one
#     cluster = get_obj(content, [vim.ClusterComputeResource], cluster_name)
#
#     resource_pool = cluster.resourcePool
#
#     # set relospec
#     relospec = vim.vm.RelocateSpec()
#     relospec.datastore = datastore
#     relospec.pool = resource_pool
#
#     # Need identity Specification
#     ident = vim.vm.customization.Sysprep()
#     ident.guiUnattended = vim.vm.customization.GuiUnattended()
#     ident.guiUnattended.autoLogon = True #the machine does not auto-logon
#     ident.guiUnattended.password  = vim.vm.customization.Password()
#     ident.guiUnattended.password.value = "Voyager1!"
#     ident.guiUnattended.password.plainText = True  #the password is not encrypted
#     ident.userData = vim.vm.customization.UserData()
#     ident.userData.fullName = "Voyager-CI"
#     ident.userData.orgName = "DellEMC"
#     ident.userData.computerName = vim.vm.customization.FixedName()
#     ident.userData.computerName.name = vm_name
#     ident.identification = vim.vm.customization.Identification()
#
#     clonespec = vim.vm.CloneSpec()
#     clonespec.location = relospec
#     clonespec.powerOn = True
#     custspec = vim.vm.customization.Specification()
#     custspec.identity = ident
#     globalIpSettings = vim.vm.customization.GlobalIPSettings()
#     custspec.globalIPSettings = globalIpSettings
#     ipSettings = vim.vm.customization.IPSettings()
#     ipSettings.ip = vim.vm.customization.FixedIp(ipAddress=ipAddress.ip)
#     ipSettings.subnetMask = ipAddress.subnetMask
#     ipSettings.gateway = ipAddress.gateway
#     ipSettings.dnsServerList = ipAddress.dnsServerList
#     adapterMap = vim.vm.customization.AdapterMapping()
#     adapterMap2 = vim.vm.customization.AdapterMapping()
#     adapterMap.adapter = ipSettings
#     custspec.nicSettingMap = [adapterMap, adapterMap2]
#     clonespec.customization = custspec
#
#     print ("cloning VM...")
#     task = template.Clone(folder=destfolder, name=vm_name, spec=clonespec)
#     wait_for_task(task)
