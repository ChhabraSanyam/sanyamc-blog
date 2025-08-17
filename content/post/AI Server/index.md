---
title: Self-Hosting an AI server
description: Creating a Headless Server with GPU support to host all my AI locally
date: 2025-01-15
categories:
  - HomeLab
  - AI
image: cover.jpg
---

> # Introduction

- I am going to install Ubuntu Server on a PC with a GPU, to make a Headless server, to run all my AI locally.
- I will run a local LLM using Ollama and Image generation using stable diffusion, on a GUI using Open WebUI.
- I will be using my old laptop with an NVIDIA gpu, to dualboot Ubuntu server, with the windows 10 pre-installed.

- *Note*: All the AI tools mentioned, can also be installed and run on any computer (with any os), and a dedicated linux gpu server is not compulsory.

- **Prerequisites:** 
	* A Computer with atleast 8gb ram & a GPU (preferably NVIDIA)
	* An empty USB drive (atleast 8gb)
	* An extra drive on the computer to install Ubuntu Server on (If dual-booting with previously installed OS)


## Preparing the Server (setting up dependencies)

### Installation of Ubuntu Server

1. ***Create a bootable usb, flashed with ubuntu server image*** : The ISO file can be downloaded from [Ubuntu's Website](https://ubuntu.com/download/server). Software such as *Rufus* or *BalenaEtcher* can be used to flash the image to the usb drive.
2. ***Boot from the usb drive with Ubuntu Server Image*** : Turn off the computer and boot into bios, by spamming the bios key for your pc. From the boot menu, select the USB drive.
3. ***Install Ubuntu Server*** : Press enter to select Try or Install Ubuntu Server. It is a pretty standard OS installation. Press Enter to Confirm, Arrow keys to move between the options, and space to select.
	- Choose your language
	- Select Keyboard layout
	- Choose installation type as Ubuntu Server & also select Search for 3rd-party drivers
	- Setup your Network Configuration. It is recommended to use LAN and also manually bind your pc a static ip instead of using DHCP
	- Set proxy if required
	- Let Ubuntu test default Mirror and proceed
	- Setup your storage configuration. It is recommended to allot a full disk for installation
	- Re-confirm your Installation drive, so as to not wipe anything important, then continue
	- Fill in your information including your name, name for the server, username and password
	- If Ubuntu found any GPU drivers, it will prompt for install confirmation
	- Skip Ubuntu Pro for now
	- Select install OpenSSH server to access your server remotely using another pc over ssh. Also import [SSH keys](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent) using GitHub, to not have to authenticate everytime you ssh into the server.  Also select Allow Password Authentication, to allow other devices without Authorised keys, to login by using credentials
	- Select any snaps(packages) you want to be installed automatically
	- Let Ubuntu server install on your PC, then reboot. also remove the installation media (pendrive) while rebooting.

### Post-Install Setup

Now whenever the PC turns on, you will be greeted the the grub bootloader menu, where you can select which os you want to boot into, Ubuntu or any previously installed OS. Select Ubuntu and after it boots up, login using the username and password set during installation.

1. *Updating Repositories and packages* :
```
sudo apt update && sudo apt upgrade -y
```

2. *Updating the Main partition to use all the free storage available* : by default, only about half of the drive is available as usable storage
```
sudo lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv && sudo resize2fs /dev/ubuntu-vg/ubuntu-lv
```

3. *Prevent Laptop from sleeping when lid closed & screensaver (optional, for laptops only)* :
```
sudo nano /etc/systemd/logind.conf
```
- Uncomment & set the HandleLidSwitch settings to *ignore*, then save & exit : 
	`HandleLidSwitch=ignore` 
	`HandleLidSwitchExternalPower=ignore`                       
	`HandleLidSwitchDocked=ignore`
```
sudo systemctl restart systemd-logind.service
```

```
sudo nano /etc/default/grub
```
- Set the time for display to sleep (in seconds), then save & exit :
	`GRUB_CMDLINE_LINUX="consoleblank=60"`
```
sudo update-grub
```

### Setting up GPU

1. *Installing GPU drivers* : [Ubuntu Documentation](https://ubuntu.com/server/docs/nvidia-drivers-installation)
```
sudo ubuntu-drivers install
```
- Reboot the computer : `sudo reboot`
- Testing (nvidia) drivers : `nvidia-smi`

2. *Installing NVIDIA container toolkit (Nvidia GPUs only)* : [Official Documentation](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
```
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
```
```
sudo apt-get update
```
```
sudo apt-get install -y nvidia-container-toolkit
```

### Docker installation & setup (for running containers)

- [Install Docker](https://docs.docker.com/engine/install/ubuntu/) : 
```
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
```
```
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

- [Post-installation steps](https://docs.docker.com/engine/install/linux-postinstall/) : 
```
## Manage Docker without prefacing the docker command with sudo

sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker
```
```
## Configure Docker to start on boot

sudo systemctl enable docker.service
sudo systemctl enable containerd.service
```

Configuring (nvidia) GPU-acceleration support for Docker Containers : 
```
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```
Also, reboot the PC : `sudo reboot`

#### Install Portainer (GUI for managing Docker Containers)

[Documentation](https://docs.portainer.io/start/install-ce/server/docker/linux)
```
docker volume create portainer_data
```
```
docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest
```
To check the container status : `docker ps`

Access the Portainer GUI : `https://{server_ip}:9443`


## Installation & Setup of AI tools

### Ollama (for local LLMs)

- Install [Ollama](https://ollama.com/)
```
curl -fsSL https://ollama.com/install.sh | sh
```

- To also expose Ollama API on the network : [Documentation](https://github.com/jmorganca/ollama/blob/main/docs/faq.md#how-can-i-expose-ollama-on-my-network)
```
systemctl edit ollama.service
```
Add these lines to change the bind address & expose Ollama on the network :
```
[Service]
Environment="OLLAMA_HOST=0.0.0.0"
```
Then restart ollama : 
```
systemctl daemon-reload
systemctl restart ollama
```

- To Download a Model : [Models list](https://ollama.com/search)
```
ollama pull llama3.2
```
To Run the Model : 
```
ollama run llama3.2
```

- Ollama Integrations : https://github.com/ollama/ollama#extensions--plugins

### Automatic1111 (Stable Diffusion: for Local Image Generation)

[Documentation](https://github.com/AUTOMATIC1111/stable-diffusion-webui?tab=readme-ov-file)

1. Pre-requisites :
```
sudo apt install -y make build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev git
```

2. Setup [*Pyenv*](https://github.com/pyenv/pyenv)
```
curl -fsSL https://pyenv.run | bash
```
```
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
echo '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(pyenv init - bash)"' >> ~/.bashrc
echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.bashrc
```
```
source ~/.bashrc
```

```
pyenv install 3.10.6
pyenv global 3.10.6
```

3. Install StableDiffusion WebUI
```
wget -q https://raw.githubusercontent.com/AUTOMATIC1111/stable-diffusion-webui/master/webui.sh
```
```
chmod +x webui.sh
./webui.sh
```

- Download SD models : https://civitai.com/models
```
## Transfer model to ubuntu server

scp /path/to/downloaded/model/{model_name}.safetensors {username}@{server.ip}:~/stable-diffusion-webui/models/Stable-diffusion/
```
*Note* : You may also delete the default SD 1.5 model

- *Additional Configuration* : 
```
cd stable-diffusion-webui
nano webui-user.sh
```
Uncomment the COMMANDLINE_ARGS line set the following arguments :
```
export COMMANDLINE_ARGS="--xformers --medvram --opt-split-attention --listen --api"
```
`--xformers` : Only for NVIDIA GPUs

- *Note* : Use the `webui.sh` script present inside the stable-diffusion-webui to run StableDiffusion with the specified Arguments
The Stable Diffusion WebUI should be accessible at : `{server_ip}:7860`

### Open WebUI (for an interactive GUI)

[Installation](https://docs.openwebui.com/) :

```
docker run -d --network=host -v open-webui:/app/backend/data -e OLLAMA_BASE_URL=http://127.0.0.1:11434 --name open-webui --restart always ghcr.io/open-webui/open-webui:main
```

The UI should be accessible at : `{server_ip}:8080`

- Additional Configuration : You can also set a default model, and enable Memory under `Settings -> Personalization`. Some other settings to enable are under `Admin Panel -> Settings` 
	- Under *Documents*, Enable *PDF Extract Images (OCR)*
	- Under *Web Search*, enable *Web Search* and set Engine to DuckDuckGo
	*Note*: OpenWebUI also has the inbuilt functionality to use Documents for context aswell. It is also possible to add System Prompts to customize the model's responses

- To Integrate Image Generation (with prompt generation) : 
	- Go to `Admin Panel -> Settings -> Images` 
	- Set Image *Generation Engine* to *Automatic1111*, and set *base url* to `http://127.0.0.1:7860` 
	- Select the Default model and enable Image Generation
	- Now just press the + icon in chat and select image, to generate images.

- *Note*: If you have low vram (<=4GB), Image generation might cause *Out of Memory* errors. To help with that, Ollama can be set to unload the model from memory everytime, after generating a response. 
```
systemctl edit ollama.service
```
Add this Environment Variable under [Service]
```
Environment="OLLAMA_KEEP_ALIVE=0"
```
*Note* : It can result in slower response times, as ollama needs to load the model into memory everytime