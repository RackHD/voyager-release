# Project Voyager
The one tool to provision, health-monitor and scale the entire datacenter.
![Voyager Deployment](https://github.com/RackHD/voyager-release/raw/master/VoyagerRelease.png)

Copyright © 2017 Dell Inc. or its subsidiaries.  All Rights Reserved. 

## Voyager Source Code
[Voyager Houston](https://github.com/RackHD/voyager-houston)  
[Voyager CLI](https://github.com/RackHD/voyager-cli)  
[Voyager IPAM Service](https://github.com/RackHD/voyager-ipam-service)  
[Voyager Secret Service](https://github.com/RackHD/voyager-secret-service)  
[Voyager RackHD Service](https://github.com/RackHD/voyager-rackhd-service)  
[Voyager Inventory Service](https://github.com/RackHD/voyager-inventory-service)  
[Voyager Cisco Engine](https://github.com/RackHD/voyager-cisco-engine)  
[Voyager Utilities](https://github.com/RackHD/voyager-utilities)  

## Voyager Requirements
### VirtualBox
Go to the [VirtualBox Download Page](https://www.virtualbox.org/wiki/Downloads) and click the link for *Windows hosts* to download the latest installer for Windows (currently 5.1.10).

When the installer downloads, make sure to run it as an Administrator (Go to your Downloads folder -> Right click -> Run As Administrator -> Click Yes).

Follow the default instructions in the installer. This process will disconnect your computer's network interfaces temporarily. Click Finish after completing the installation.


### Vagrant
Go to the [Vagrant Download Page](https://www.vagrantup.com/downloads.html). Click on the link for *Windows Universal (32 and 64-bit)*. This will download the Vagrant installer for the latest version (currently 1.9.0).


When the installer downloads, run it. Follow the default instructions to install Vagrant. When the installer prompts you to restart your computer, click Yes to finish the installation.


When the installation is finished, open a command prompt (Start -> type cmd). Run the command `vagrant plugin install vagrant-vbguest`  


### Git & Git-Bash
Visit [Git Download Page](https://git-scm.com/download). Select Windows to download the latest installer for Windows (currently 2.11.0).

When the installer downloads, make sure to run it as an Administrator (Go to your Downloads folder -> Right click -> Run As Administrator -> Click Yes).

Follow the default instructions in the installer.

## Running Voyager
### Get the latest release
Go to the [Voyager release page](https://github.com/RackHD/voyager-release/releases) and download the latest release. Click the link for *Source code (zip)* in the section that shows *Voyager Release vXYZ*, where *XYZ* is the latest release number. 
Navigate to the location you downloaded to and unzip the file named *voyager-release-xyz.zip*, where *xyz* is the version number. This can be done by Right click -> Extract All, or using a program such as [WinZIP](http://www.winzip.com), [7ZIP](http://www.7-zip.org/) or similar tools. 
### Preparing Voyager to run
Open **Git Bash** (Start -> type Git Bash) and navigate to the directory you extracted the release to. For example, if you put the release on your Desktop, run `cd /c/Users/<YOUR_USERNAME>/Desktop/voyager-release-xyz`
### If your environment does not have internet access
Many use cases for Voyager will involve an environment where the user does not have any internet access (i.e. an unprovisioned lab, with no wi-fi or networking set up yet). If that is the case, follow this set of instructions. If not, go to the next section. 

The script that starts Voyager will download several things from the internet. To prepare Voyager to run without internet access, run  
```
./run-voyager.sh --prepare-offline
```

This will download two large VM images from Hashicorp Atlas using Vagrant. If any prompts appear requesting permissions for VirtualBox, allow them. It will attempt to start the VMs (one containing RackHD and one containing several Docker containers running the Voyager components). If it succeeds, it will suspend the VMs, so they can be resumed later when the user is in their target environment.  

When you are ready to run Voyager, connect the machine running Voyager to the target hardware via Ethernet. Run the script 
```
./run-voyager.sh --offline
```

### If your environment has internet access
If your environment does have Internet access, connect the machine running Voyager to the target hardware via Ethernet. Ensure that your Voyager machine still has an internet connection. This will likely require making sure the Ethernet and WiFi interfaces are both active. An alternative is to make two Ethernet connections (one to the internet and one to the target hardware) using a USB-to-Ethernet adapter or something similar.   

When the above steps are done, run the script  
```
./run-voyager.sh
```

## Using Voyager
Once the above ```./run_voyager.sh``` completes successfully, there will be two vagrant VMs running in the background.  In order to interact with Voyager, you need to change directories to where the command-line binary exists. We release binaries for Windows, OS X, and Linux which are in their respective directories in ```cli/```

Our cli is called ```mcc``` after voyager-cli. It's how we interact with Houston, our management service. In order to be able to get information from Houston, we need to point the binary to use the Voyager VM's IP, which defaults to `192.168.50.5:8080`.

#### To set the target IP
For example, running on Windows we would run the following:
`cd cli/windows`
`./mcc.exe target http://192.168.50.5:8080` where that `ip:port` is the default endpoint of the Houston service.

#### To see information about nodes
```./mcc.exe nodes```
This will display a table with all node information.

## Troubleshooting
### 1) I get an error that looks like this!  
```
There was an error while executing `VBoxManage`, a CLI used by Vagrant
for controlling VirtualBox. The command and stderr is shown below.
Command: ["startvm", "d1b40892-ad8b-4ef7-afad-02b92eb674da", "--type", "headless"]
Stderr: VBoxManage.exe: error: Failed to open/create the internal network 'HostInterfaceNetworking-VirtualBox Host-Only Ethernet Adapter #2' (VERR_INTNET_FLT_IF_NOT_FOUND).
VBoxManage.exe: error: Failed to attach the network LUN (VERR_INTNET_FLT_IF_NOT_FOUND)
VBoxManage.exe: error: Details: code E_FAIL (0x80004005), component ConsoleWrap, interface IConsole
```
**Solution**  
There is a conflict with the VirtualBox Host-Only Network Adapter. Re-install Virtualbox using an older version of the adapter with these steps.  
*a)* Uninstall VirtualBox. Start -> Uninstall A Program  
*b)* Open a Windows Cmd prompt. Start -> cmd.  
*c)* Run the VirtualBox installer via the command line, like the example below, replacing `<YOUR_USERNAME>` with your Windows username. Make sure to include the `msiparams` flag as shown. 
```
C:\Users\<YOUR_USERNAME>\Downloads\VirtualBox-5.0.11-104101-Win.exe -msiparams NETWORKTYPE=NDIS5
```  

### 2) I get an error that looks like this!

```
VBoxManage.exe error: VT-x is not available (VERR_VMX_NO_VMX) code E_FAIL
```

There are two possible causes for this issue:
##### VT-x is not enabled in BIOS
*a)* Reboot your computer. During startup, press the correct key to enter BIOS settings. (usually F2, possibly F10 or F12)
*b)* Find the BIOS setting for Virtualization, and ensure VT-x is enabled. 

##### Hyper-V is enabled in Windows
*a)* Start -> type Turn Windows Features On or Off  
*b)* Uncheck all boxes under Hyper-V


## Licensing

Licensed under the Apache License, Version 2.0 (the “License”); you may not use this file except in compliance with the License. You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

RackHD is a Trademark of Dell EMC
