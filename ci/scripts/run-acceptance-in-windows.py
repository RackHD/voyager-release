from subprocess import Popen, PIPE, call
import unittest
import os
import shutil
import ssl
import atexit
import re
import json
import urllib2
import acceptance_utils as au
from pyVim.connect import SmartConnect, Disconnect
from pyVmomi import vim
from time import sleep

unittest.TestLoader.sortTestMethodsUsing = lambda _, x, y: cmp(y, x)

class MyTestCase(unittest.TestCase):
    @classmethod
    def setUpClass(self):
        self.go_path = os.environ['GOPATH']
        self.project_voyager_path = os.path.join(self.go_path, "src/github.com/RackHD")
        self.voyager_release_path = os.path.join(self.project_voyager_path, "voyager-release")
        self.github_username = os.environ['GITHUB_USERNAME']
        self.github_password = os.environ['GITHUB_PASSWORD']
        self.mcc_file_path = os.path.join(self.voyager_release_path, "cli/windows/mcc.exe")

        self.vsphere_server = os.environ['VSPHERE_SERVER']
        self.vsphere_user = os.environ['VSPHERE_USER']
        self.vsphere_password = os.environ['VSPHERE_PASSWORD']
        self.acceptance_node_vm_count = int(os.environ['ACCEPTANCE_NODE_VM_COUNT'])
        self.wats_env_num = os.environ['WATS_ENV_NUM']

        self.max_reties = 30
        self.backoff_delay = 10
        os.chdir(self.voyager_release_path)
        call(["vagrant", "plugin", "install", "vagrant-vbguest"])

        # Test offline preparation works
        # p = Popen(["./run_voyager.sh", "--prepare-offline"], stdin=PIPE)
        # p.communicate(input="1")
        # p = Popen(["./run_voyager.sh", "--offline"], stdin=PIPE)
        # p.communicate(input="2")

        process = Popen(["./run_voyager.sh"], stdin=PIPE)
        process.communicate(input="2")

    def test_target(self):
        process = Popen([self.mcc_file_path, "target", "http://192.168.50.5:8080"], stdin=PIPE, stdout=PIPE, stderr=PIPE)
        output, _ = process.communicate()
        self.assertEqual(output, 'Target set to http://192.168.50.5:8080\n')

    def test_no_nodes(self):
        process = Popen([self.mcc_file_path, "nodes"], stdin=PIPE, stdout=PIPE, stderr=PIPE)
        output, _ = process.communicate()
        self.assertEqual(output, '+----+------+--------+----+\n| ID | TYPE | STATUS | IP |\n+----+------+--------+----+\n+----+------+--------+----+\n')

    def test_2_nodes_added(self):
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        # connect this thing
        service_instance = SmartConnect(
            host=self.vsphere_server,
            user=self.vsphere_user,
            pwd=self.vsphere_password,
            port=443,
            sslContext=ctx)
        # disconnect this thing
        atexit.register(Disconnect, service_instance)

        # get content
        content = service_instance.RetrieveContent()
        for index in range(1, self.acceptance_node_vm_count + 1):
            vm_name = "Voyager-vBMC-%03d-%s" %(index, self.wats_env_num)
            vm = au.get_obj(content, [vim.VirtualMachine], vm_name)
            au.Reboot_vm_and_wait_for_ip(vm)

        self.wait_for_respose_size("http://192.168.50.4:8080/api/common/nodes", self.acceptance_node_vm_count)

        process = Popen([self.mcc_file_path, "nodes"], stdin=PIPE, stdout=PIPE, stderr=PIPE)
        output, _ = process.communicate()

        nodes_regex = re.compile("\|\s*([0-9A-Za-z]+)\s*\|\s*(compute|switch)\s*\|\s*(Discovered|Added)\s*\|(\s*)\|\n")
        count = len(nodes_regex.findall(output))
        self.assertEqual(count, self.acceptance_node_vm_count)
        all_matches = nodes_regex.finditer(output)
        for node_match in all_matches:
            self.assertEqual(node_match.group(2), "compute")
            self.assertEqual(node_match.group(3), "Added")

    @unittest.skip("Skipping because Discovered status seems to be unstable")
    def test_2_nodes_discovered(self):
        self.wait_for_respose_size("http://192.168.50.4:8080/api/common/catalogs", self.acceptance_node_vm_count * 7)
        process = Popen([self.mcc_file_path, "nodes"], stdin=PIPE, stdout=PIPE, stderr=PIPE)
        output, _ = process.communicate()

        nodes_regex = re.compile("\|\s*([0-9A-Za-z]+)\s*\|\s*(compute|switch)\s*\|\s*(Discovered|Added)\s*\|(\s*)\|\n")
        count = len(nodes_regex.findall(output))
        self.assertEqual(count, self.acceptance_node_vm_count)
        all_matches = nodes_regex.finditer(output)
        for node_match in all_matches:
            self.assertEqual(node_match.group(2), "compute")
            self.assertEqual(node_match.group(3), "Discovered")

    def wait_for_respose_size(self, url, size):
        try:
            response = json.loads(urllib2.urlopen(url).read())
        except:
            response = []
        num_tries = 1
        while len(response) < size and num_tries < self.max_reties:
            num_tries += 1
            sleep(self.backoff_delay)
            try:
                response = json.loads(urllib2.urlopen(url).read())
            except:
                pass

    #@classmethod
    #def tearDownClass(self):
    #    os.chdir(self.voyager_release_path)
    #    call(["./run_voyager.sh", "--destroy"])
    #    call(["vagrant", "box", "remove", "voyager/rackhd-dev", "-f"])
    #    call(["vagrant", "box", "remove", "voyager/AcceptanceBase", "-f"])
    #    shutil.rmtree(self.go_path)

if __name__ == '__main__':
    unittest.main()
