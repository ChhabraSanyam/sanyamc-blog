---
title: Building a Home Server
description: Setting up a headless Home Server for self hosting using Proxmox
date: 2026-07-28
categories:
  - HomeLab
image: cover.png
---

> # Introduction

Proxmox VE is a type 1 hypervisor which provides a headless web-based UI to manage VMs and LXCs. I am going to setup 2 devices, for a multi-node cluster.

## Requirements
- [Minimum Req.](https://www.proxmox.com/en/proxmox-virtual-environment/requirements) : A PC with virtualization support and sufficient ram and cpu cores to be able to run VMs/containers. (If the device does not support Hardware virtualization, it can still run LXC Containers)
- A Wired Internet Connection - It is not recommended to use wifi.

# Proxmox Installation
- Download latest Proxmox VE ISO from [here](https://www.proxmox.com/en/downloads/proxmox-virtual-environment)
- Flash the image to a pendrive (8gb or greater) using Rufus/Balena Etcher
- Before installing Proxmox, change these settings in the BIOS:
	- Turn off Secure Boot
	- Turn on Hardware Virtualisation (VT-x/AMD-V or Intel VT-d/AMD IOMMU)
	- Also turn on Hyper Threading if present
- Now, boot using the Proxmox install media (pendrive)
- Follow the Proxmox Installation GUI:
	- Select the disk to install Proxmox on (it would be wiped, so double check)
	- The password you set will be used as the root password, and for the Web-ui login
	- In the Network Configuration, set hostname as {node_name}.local, and set the static IP (CIDR) for the machine (the IP addresses following the machine's IP will be used for VMs/LXCs, so choose the IP with ample free addresses afterwards as per your router configuration). ex. - `192.168.1.200`
- After installation, reboot and you'd be greeted with the shell. You may now disconnect all external accessories from that PC (monitor, KBM). There is no need to mess with the shell, as everything would be managed using the integrated web-ui, which also provides web shell access.
- Now, navigate to the web interface using the IP of the device set earlier. The default port for the web-ui is `8006`.
eg. - `https://192.168.1.200:8006`

# Proxmox Setup

The default username is `root` and password is the one set during installation.

## Post Install Setup

### [Proxmox VE Helper-Scripts](https://community-scripts.org/)
These Helper scripts provides a lot of prebuild templates for self hosting various services with ease. Run these scripts using the web shell proxmox provides.

#### [PVE Post Install Script](https://community-scripts.org/scripts/post-pve-install)
This script provides options for managing Proxmox VE repositories, including disabling the Enterprise Repo, adding or correcting PVE sources, enabling the No-Subscription Repo, adding the test Repo, disabling the subscription nag, updating Proxmox VE, and rebooting the system.

By default, you will not receive proxmox updates without an active enterprise subscription, to fix that this script adds the no subscription (community) repo to proxmox.

Here are my recommended options for the script:
	Disable Enterprise repos
	Enable No-Subscription repos
	Select no to PVE-Test repo for maximum stability
	Disable Subscription nag
	Don't disable High Availability service if you want to create a HA cluster using 2 or more nodes, for replication and backup. If not, then disable it to free up system resources. It can always be reactivated later aswell, under the system tab of the node
	Update and reboot PVE
Also, you can always rerun the script again in the future to apply any other optimizations.

### Making the default bridge VLAN-aware

Proxmox VLANs offer a multitude of benefits for your virtual environment. By leveraging VLANs in your Proxmox network, you can enhance security, improve performance, and streamline network management.
Know more about [VLANs](https://youtu.be/UB-tYRP2weM?si=pX7BZMLB0aBKtzpp)

To VLAN enable your default bridge:

- Go to your node under datacenter, then under System -> Network -> default Linux bridge (vmbr0), click edit, and check the VLAN aware checkbox. Click ok, then Apply Configuration. Restart the proxmox server to apply the changes.

### Setting up ssl certificates for Proxmox

The proxmox webui can be secured by configuring ssl certificates which will also remove the warning popups saying the website is not secure.
The typical way to do this is using LetsEncrypt, but it is a bit long and complicated process, and is not completely free. You will need a domain name, and then will need to use cloudflare dns for managing the domain. 
It is also required to regularly renew the Lets Encrypt certificate, which can be automated using certbot, but requires additional setup.
Do this only if you plan on exposing the web-ui to the internet, for remote access.
For the detailed process, refer to [this](https://youtu.be/2_PhwHOxytM?si=IEJxbR-iOX4WoLQ2)

### Setting up Two-Factor Authentication

If you plan to expose your proxmox server to the internet, it is recommended to setup multifactor auth.
To set up 2FA:
	Datacenter -> permissions -> Two Factor -> Add -> TOTP.
Use any Authenticator app (Google/Microsoft Authenticator) to set it up using the QR code

### Bonus (For Laptops)

#### Prevent Laptop from going to sleep on closing the Lid

- Open shell, and edit the service login file
	`/etc/systemd/logind.conf`
	Use nano/vim as per preference
- Find and uncomment the 3 HandleLidSwitch settings, and set each of them to *ignore* (from suspend)
```
HandleLidSwitch=ignore
HandleLidswitchExternalPower=ignore
HandleLidswitchDocked=ignore
```
- Restart the login service to apply changes
	`systemctl restart systemd-logind.service`

#### Screensaver (Turn off display on idle)

Even on closing the lid of the laptop, the screen stays on continuously, which may cause the screen to burn out over time, making it unusable

- Using the shell, edit the Grub file
	`/etc/default/grub`
- To put the screen to sleep after 1 min, set
	`GRUB_CMDLINE_LINUX="consoleblank=60"`
- To apply the changes
	`update-grub`


## Setting up Storage

There are basically two different classes of storage types:

1. **File level storage:** They are in general more flexible than any Block level storage (see below), and allow you to store content of any type. On file based storages, snapshots are possible with the _qcow2_ format.
2. **Block level storage:** Allows to store large _raw_ images. It is usually not possible to store other files (ISO, backups, ..) on such storage types.

First lets talk about the major storage types proxmox supports:

#### Directory
This is a file level storage and is basically similar to a folder. It is the only type capable of storing iso images and templates as well as backups. It Although it is possible to store VMs and containers on it, it is not recommended to do so, especially on an SSD as it can degrade the SSD’s health and has greater overhead. The best use case for this is for the smaller sized boot drive to store iso images, container templates and backups

#### LVM 
It is a block level storage thus it can cannot store anything other than VM disk images and containers. It has very little overhead and preferred over directory to store VMs and Containers. But LVM normally allocates blocks when you create a volume, i.e. storage is pre allocated for volumes in LVM, which can result in a lot of wasted storage. Also, It is possible to use LVM on top of an iSCSI or FC-based storage. That way you get a shared LVM storage.

#### LVM-thin
It is similar to LVM and is a block type storage. But, LVM-thin but fully supports snapshots and clones efficiently, and storage is dynamically allocated for volumes. This behavior is called thin-provisioning, because only the blocks that the guest system actually use will be written to the storage i.e. With thin provisioning activated, volumes can be much larger than physically available space.

Say for instance you create a VM with a 32GB hard disk, and after installing the guest system OS, the root file system of the VM contains 3 GB of data. In that case only 3GB are written to the storage, even if the guest VM sees a 32GB hard drive. In this way thin provisioning allows you to create disk images which are larger than the currently available storage blocks. You can create large disk images for your VMs, and when the need arises, add more disks to your storage without resizing the VMs' file systems.

This means that for example if you have 100 gb storage available, but you can still assign a 150 gb hard disk to a VM and as long as it actually uses less than 100 gb of storage everything will work fine.

Warning: If the storage runs full, all guests using volumes on that storage receive IO errors. This can cause file system inconsistencies and may corrupt your data. So it is advisable to avoid over-provisioning of your storage resources, or carefully observe free space to avoid such conditions.

It must be mentioned that LVM thin pools cannot be shared across multiple nodes, so it can only be used as local storage.
Even though thin provisioning does cause a negligible performance loss i would recommend using this over lvm in most cases.

#### ZFS
ZFS is technically a file level storage, but Disk images for VMs are stored in ZFS volume (zvol) datasets, which provide block device functionality. Hence it provides a hybrid between both file and block level storage. ZFS is probably the most advanced system, and it has full support for snapshots and clones. ZFS supports storage pools with varying levels of data redundancy. When a bad data block is detected, ZFS fetches the correct data from another redundant copy and repairs the bad data, replacing it with the correct data. ZFS is used as an alternative to raid which is used a way of storing the same data in different places on multiple hard disks to protect data in the case of a drive failure.

ZFS is only recommended when you have multiple harddisks. In a ZFS setup, for example if you have two 1tb drives (2 tb total) and use one as a mirror drive, then only 1tb of net storage will be available for use. ZFS is more suited for more advanced users like developers who constantly move data around different disks and servers. For actually utilising benefits of ZFS, you may need and enterprise class ssd for dedicated cache/ log disk. Also, ZFS depends heavily on memory, so it is not recommended with less than 8GB ram, and over that you should have at least approx. 1 gb of ram extra for every 1tb of harddisk storage to be used. To prevent data corruption, it is recommend to use high quality ECC RAM.

ZFS may start causing issues when your hardrive gets filled upto 80-90% and the the performance also gets degraded.  Also ZFS adds a major overhead and can cause significant performance loss on old low end systems. _Hence it is not recommended for basic user to setup zfs._

(If you are experimenting with an installation of Proxmox VE inside a VM (Nested Virtualization), don’t use virtio for disks of that VM, as they are not supported by ZFS. Use IDE or SCSI instead (also works with the virtio SCSI controller type).)

Note: Do not use ZFS on top of a hardware RAID controller which has its own cache management. ZFS needs to communicate directly with the disks. An HBA adapter or something like an LSI controller flashed in “IT” mode is more appropriate.

#### Ceph 
It is also an advanced storage type which is used as shared storage in a High Availability cluster.

For more information: [https://pve.proxmox.com/wiki/Storage](https://pve.proxmox.com/wiki/Storage)

### Configuring Drives

First we need to setup our storage device because by default proxmox is not configured to use all the storage of our system. We need to perform this step before deploying any virtual machines or containers on our system.

Initially, when you go to your node you can see that only your boot drive has been configured and there are 2 partitions of that storage.

One being local which can be used to store everything but is currently only configured to be able to store iso images and container templates. it currently can’t store VMs or Containers. It has the smaller fraction of your storage right now
The other one is local-lvm, which actually has the major part of your storage but it can only be configured to be able to store Disk images of VMs and containers.

I have multiple drives, so what I am going to do is delete the local-lvm partition and actually assign all the storage to local volume then configure it to store everything including iso files, container templates and backups. Basically i am gonna use the smaller boot drive for storage, and the other bigger drive for disk images of VMs and LXCs.

Now, follow these steps to resize our partitions:
1. We will start by deleting that volume. To do that, under Datacenter -> Storage, select local-lvm and remove it. This deleted the local-lvm volume, but that storage is still not available for use. To fix that we need to use shell commands.
2. Perform the following commands:
```
// To delete local-lvm from cli
lvremove /dev/pve/data

// To reallocate the space
lvresize -l +100%FREE /dev/pve/root

// To confirm resize of main storage
resize2fs /dev/mapper/pve-root
```
You could also do this, if you have a single HDD, and use a single partition for everything. Don't do this if using a single SSD, as it may degrade its health faster.

Now when you check the local directory under your node, you can see that the size of that volume is now utilizing the full drive. But, we still have one step left to give the local directory permissions of the type of data it can store.

To do that, go to Datacenter -> storage then, select local and click edit. In the edit menu we need to specify what type of content can be allowed in this directory. By Default Disk images and containers are not allowed.

If you only have this single drive in your system, i will recommend you to select every thing in the contents section. Otherwise, if you have another storage drive for VMs and containers, you can leave Disk Image and Containers Unchecked for simplicity.

If you have other storage devices in your system aswell, follow these steps to configure them :

1. Go to your node -> Disks, under there you should see all the storage drives connected to your computer. Other than the boot drive, select the one you want to add and click wipe disk
2. This should delete all existing partitions and data on that disk. Now select it again and click initialize disk with GPT
3. Now, under the Disks dropdown menu, select the storage type you want to use between directory, lvm, lvm-thin and zfs according to your use case. If unsure, I would recommend using LVM-thin
4. Click on lvm-thin, then click Create Thinpool and under disk, select the disk you want to add, then give it a name. Make sure Add Storage is Checked. Then click Create
5. If you have other storage devices you want to add aswell, then you can create a new thin pool for lvm-thin which is the easier option.

Just make sure to edit the Content type allowed on the newly configured drives aswell. Disk image and Container should be checked, to store VMs and LXCs on that drive.

### Bonus (For advanced use cases)

It is possible to add other storage device in an existing thin pool aswell but that is a tedious process and has risks because if not done correctly, it can corrupt your proxmox installation. Make sure to do this before storing anything on the drives to prevent data loss

Here are a few commands to check the current configuration in host shell:
```
pvs
vgs
lvs
lsblk
```

First make sure your volume group (VG) called pve takes up almost the entire partition. After that, extending local-lvm is quite simple. Just make sure you don't forget to also extend metadata.

```
// Find new disk
fdisk -l

// Format the disk
cfdisk /dev/sdc    // use the correct name for the disk to add
// > New -> Primary -> Specify size in MB  
// > Write  
// > Quit  

// Create volume
pvcreate /dev/sdc1    // use correct partition name

// Add new volume to lvm
vgextend pve /dev/sdc1

// Increase volume of lvm to take advantage of new HDD
lvextend /dev/pve/data -L +251.50g    // use *vgs* command to find correct size of new volume 

lvresize --poolmetadatasize +1GB pve/data
```

If the partition already has the correct size, the following command can also be used instead of the 2nd last command, but keep in mind that they delete the LVM partition. If you do that all your data will be lost if you don't have a backup.  

First extend your metadata and then use,
`lvresize -l +100%FREE pve/data`

For more details, Follow this [guide](https://kenmoini.com/post/2018/10/quick-n-dirty-adding-disks-to-proxmox/)

## Creating a Cluster (Optional)

If you have multiple computers you want to install proxmox on, to increase your total available resources, then, you can add them in a cluster for easy management. Just make sure to give each of your proxmox servers different nodenames during the setup process in the Hostname section. But first lets under stand what Cluster, High Availability and replication is:

**Clustering:** Clustering in Proxmox involves connecting multiple Proxmox nodes together to create a distributed system. The main benefit is scalability; as your resource needs grow, you can add more nodes to the cluster. Clustering allows the system to manage multiple nodes from a single interface and aids in load balancing. However, clustering doesn't inherently provide redundancy. If a node fails, the virtual machines (VMs) or containers running on that node will be affected unless you've implemented additional measures.

**High Availability (HA):** HA, on the other hand, is specifically designed for redundancy. With HA enabled, in the event of a node failure, Proxmox can automatically start the affected VMs or containers on another node in the cluster, minimizing downtime. It does this by monitoring the status of VMs/containers across the cluster and managing their states to ensure they remain operational. HA requires a cluster to work, but a cluster doesn't inherently include HA.

**Replication:** Replication allows you to migrate VMs with less downtime by copying the contents of the HDD between local storage on different nodes. If you have shared storage (NFS, Ceph etc) then you don't need to run replication. HA monitors the state of the VM and either starts or migrates it as required to meet the desired state.

HA and replication are used together and they do require you to setup a zfspool storage, so it is only recommended for Advance users to set this up.

In summary, clustering in Proxmox provides a way to scale your resources and manage them from a single interface, while high availability adds a layer of redundancy to maintain service continuity in the event of a node failure. They often work together to create a more robust, scalable, and resilient system.

Even If you don’t want to use High Availability and replication, Clustering offers the following benefits:

- Centralized web-based management that allows you to view all the nodes and their statistics from any node.
- Seamless migration of virtual machines and containers between physical hosts.
- Faster deployment of resources.
- Cluster-wide services like a firewall and High Availability.
- Use of pmxcfs, a database-driven file system. This is a file system for storing configuration files. It is replicated in real-time across all the proxmox nodes using corosync.

Note: You should Create a cluster before creating any VMs or containers, as it may cause problems while joining a cluster if multiple nodes have VMs or Containers with the same ID.

### Setting up the Cluster

1. First, go to the web ui of your primary proxmox node. Then go to datacenter and then click on cluster. Now click on Create Cluster
2. Now give your cluster a name and select the server’s static ip under cluster network then click create. Wait for it to finish, when it says TASK OK, close the Task Viewer
3. Now click on Join Information on the top, then click on Copy Information
4. Now, go to the Web UI of your other Proxmox Nodes that you want to add to the cluster, and go to datacenter, then click on cluster, and then click Join Cluster and paste the join information you copied earlier from the primary node. Now type your primary node’s password in the password section and click Join
5. Now, it is going to take a while to finish setting up the cluster and the process may get stuck inbetween and show and error or connection lost. Just refresh the web interface pages of all your nodes and after logging in again you will see under the Cluster Information Section, that they joined the cluster successfully

Now, under datacenter you can see and manage all your nodes from any single node’s web ui, aswell as effortlessly migrate any VM or container from one node to another.

There is an issue where if you have setup any VM or Container before joining a cluster, it may not work and give an error. To fix that issue you can refer to [this](https://youtu.be/rMKwEOL2HSA?si=yGo6HosJpkxmd2wQ)

### High Availability and Replication

To setup HA and replication, you can refer to [this](https://youtu.be/08b9DDJ_yf4?si=7iZYYydR-vssv9a2)

### Bonus Tip

Proxmox cluster has the concept of "quorum" and it's ensuring stability of the cluster's state. By default, you will need at least greater than **(total number of nodes/2)** nodes online in order to start/use containers or VMs.
Each node will have 1 vote, and to operate your cluster, you need to have majority numbers. If the minimum numbers of votes are not met, it will throw an error “TASK ERROR: cluster not ready - no quorum?”, whenever your proxmox tries to autostart VMs or containers on boot or you manually try to start them. 
In some cases even the shell would not open. To fix this, first you need access to the shell, either via the web ui or using ssh. Then you can use the command: `pvecm expected 1`
This will maually set expected votes to 1. But, If it gives the error” Cannot initialize CMAP service”, make sure corosync service is running using the command: `systemctl status corosync.service`

But this is only a one time solution, and you will need to run the command every-time to fix the issue.
This step can also be automated by making a Bashscript and autorunning it on boot.
- Make a new script using: `nano quorum.sh`
- Paste the following
```bash
#!/bin/bash

pvecm expected 1
```
- Make the script executable using: `chmod +x quorum.sh`
- To make it autorun on boot, create a new service file using: `nano /etc/systemd/system/quorum.service`
- Paste the following
```bash
[Unit]
Description=Quorum skip
After=network.target

[Service]
ExecStartPre=/bin/sleep 30
ExecStart=/root/quorum.sh

[Install]
WantedBy=multi-user.target
```
- Refresh the services list using: `systemctl daemon-reload`
- Enable the autostart on boot using: `systemctl enable quorum.service`

On the next reboot, the quorum will automatically be met.


# Setting up VMs and LXCs

## Virtual Machines

The process of setting up a VM remains the same for all linux distros but there are a few extra setup steps required for windows, especially windows 11 due to its requirements.

1. Download the iso installer files for an OS, and upload it to proxmox, using the webui, under: your_node->local(storage)->ISO Images
2. Click Create VM button on top, and just follow the VM creation wizard.
3. Under the OS section, when you select the iso file, proxmox should automatically detect the Guest OS type, else it can be set manually. This is important, because according to the Guest OS, the optimal system settings would be configured automatically.

### VirtIO Drivers

VirtIO Drivers are paravirtualized drivers for kvm/Linux. In short, they enable direct (paravirtualized) access to devices and peripherals for virtual machines using them, instead of slower emulated ones. This massively improves the performance of a VM.

Linux has them preinstalled, but Windows does not have native support for VirtIO devices included, so we have to manually install them. To do that we need the official kvm driver disk.

You can get the latest stable VirtIO Drivers ISO from the official [github repo](https://github.com/virtio-win/virtio-win-pkg-scripts)

You just need to download the VirtIO ISO and upload it to proxmox. Then, check the add additional drive for VirtIO drivers and then select the VirtIO ISO under that, in the VM creation Wizard

## LXC

These are a bit different than the more popular docker containers. Linux containers work on the same containerization principle as docker. They are lightweight as it shares the host’s kernel so only linux containers are possible. Windows can not be used as LXC. These work pretty similar to a CLI based Linux distro but require much less resources than running it on a VM. But a VM is much more secure with far less risk of harming the Host OS (proxmox) if in case it gets compromised. This is applicable more if you are going to expose that to the internet.
Proxmox provides a few LXC templates, but the best part is, it also supports the universal container template format, and allows downloading those templates from the OCI registry. That means, it is possible to use the docker container templates for LXCs aswell

To setup an LXC:
- Get container templates from under you_node->local(storage)->CT templates.
- Click Create CT button on the top, and just follow the LXC creation wizard.

## Bonus Tip
Instead of setting up all VMs and Containers manually, check out the ***[Proxmox VE Helper Scripts](https://community-scripts.org)***
It provides a lot of scripts to easily setup popular services to self host, with no hassle.

# Bonus

## Windows on Proxmox

https://youtu.be/fupuTkkKPDU?si=ZV7H_grfZNZ68rBa

## Proxmox Networking

https://youtu.be/zx5LFqyMPMU?si=qlU4RtaiZhqPmK5h

## SDN

https://youtu.be/_lIk9p_SyvU?si=rKtMx-mMwstiysM4

## Setup Email alerts

https://youtu.be/85ME8i4Ry6A?si=30ICKcrIh-D5ZVHr

## PCIe Passthrough
It is also possible to pass through a GPU to a VM in proxmox. Also, this only works for dedicated GPU. It is also possible to passthrough other PCIe devices such as network cards. But there are some requirements to do that. First you should have a CPU that supports IOMMU. There are different names for that technology such as VT-d/VT-x, etc.

For more information you can refer to these:

https://www.reddit.com/r/homelab/comments/b5xpua/the_ultimate_beginners_guide_to_gpu_passthrough/

https://youtu.be/_hOBAGKLQkI?si=OtquZnS-REAIfWGz
https://youtu.be/S6jQx4AJlFw?si=VO86VPvJzjLLFdiv

To passthrough a gpu to multiple LXCs : https://youtu.be/0ZDr5h52OOE?si=YacPpr5RT3d73inC

## Remote Access

For remotely accessing your self hosted services, and or the proxmox webui, there are much safer options than port forwarding.

### Cloudflare Tunnels
You require a domain name with Cloudflare as the dns manager. This method is not completely free, since domains need to be renewed. All you need to do is setup a cloudflare tunnel connector on the proxmox server, then cloudflare makes it very easy to manage which ip and ports you want to expose, using a subdomain, with no other manual firewall configuration required.
[Learn more](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/)

### VPNs
Not the traditional VPNs or reverse proxy, which still requires manual config.
Services like ***[ZeroTier](https://www.zerotier.com/)***, ***[Tailscale](https://tailscale.com/)***, ***[Twingate](https://www.twingate.com/)*** provide easy to setup Zero Trust, Mesh VPNs, and are free for personal use (with a max device limit on the free tier).
These solutions are better & more secure than traditional VPNs, as they use Split-tunneling (Split DNS), i.e. it only routes internal traffic through the vpn.
Setting these up is as simple as installing a node connector on the server, and having a client app on the device, which would be used to access the server, for the VPN connection.
