---
title: Building a Voice Assistant
description: Building a local AI home assistant with custom voice
date: 2025-06-20
categories:
  - AI
  - HomeLab
image: cover.png
---

># Introduction

I am going to setup Home Assistant for local home automation on a VM, then create a voice pipeline to setup a local AI voice assistant.
I am also going to train a custom voice model for the Voice Assistant. I am going to be cloning the voice of Yoda (from star wars)

## Setting up Home Assistant

- Install Home Assistant :  https://www.home-assistant.io/installation
- Access the WebUI : http://homeassistant.local:8123
- Create an account and then setup any or all of your IoT devices under `Settings->Devices & services`.
- Additionally, it is also possible to setup the HA companion app on mobile, and create Automations.
- Also, it is possible to setup Tailscale or ZeroTier to access HA remotely, by installing their respective Add-ons from the Addon store.

## Setting up Voice Pipeline

- Under `Settings->Add-ons` , Install the following Addons : 
	- Whisper (STT)
	- Piper (TTS)
	- Assist Microphone
	- openWakeWord
- Start all the Addons, then under `Devices & services`, add the 4 Wyoming Protocol Devices
- Also, add the Ollama Integration to connect and use an LLM as the conversation agent for the assistant, to make it smarter and remember context. Ollama could be setup on the HA host or any other PC with a GPU for better speed. I am using llama3.2
*Note*: If running ollama on the same machine, the IP for the host is usually the gateway address of the subnet of the VM (if not using bridged adapter). Also, use this command for ollama to allow commections from remote services :
```
OLLAMA_HOST=0.0.0.0 ollama serve
```
- Under `Settings->Voice Assistants`, Add Assistant, 
	- Change the name, then under Conversation Agent, select the LLM added using the Ollama Integration, which is way smarter than the default Home Assistant agent. Then in settings of ollama conversation agent, Turn `Assist` on under Control Home Assistant
	- For `Speech-to-Text`, select `faster-whisper`, and for `Text to Speech`, select piper.
	- Also, to use a wake word, `Add streaming wake word`, then under Wake word engine select `openwakeword`, and select a Wake Word.
	*Note*: To activate assistant through a wake word, a usb speaker and mic needs to be used (passthrough to the HAOS VM ,if applicable), and selected under the `Assist Microphone` addon Configuration
- To access the Assistant, use the Assist icon on HA dashboard. In the webui, it is only possible to talk to the assistant using text. To use voice, an SSL certificate needs to be added to HA to get a HTTPS connection.
- Here's a guide to get ssl certs for HomeAssistant: https://novamostra.com/2023/04/29/add-ssl-tls-certificate-to-homeassistant-web-interface/
- The easier way to converse with the assistant using voice is to use the Home Assistant Companion App on mobile.
- It is also possible to setup a Wyoming Satellite on another device to access the Voice Assistant with wake word trigger. 
	https://github.com/rhasspy/wyoming-satellite.git
*Note*: It is also possible to offload Whisper (SST) and Piper (TTS) to another device with a GPU to improve the Assistant's response speed. 
	https://github.com/rhasspy/wyoming-addons
Then add the service using the Wyoming Protocol

- It is also possible to train a custom wake word : https://www.home-assistant.io/voice_control/create_wake_word/

## Training a custom voice clone model

I will be training the voice model using `Piper`, which will give the model in a standard format (*.onnx*), which can be used in many TTS services and for the voice assistant aswell. This process requires the use of linux and an Nvidia GPU. I used WSL with Ubuntu-22.04

### Step 1: Prerequisites

Piper works best with Python-3.10 and cuda-11.7

```
sudo apt update && sudo apt upgrade
sudo apt install python3-venv python3-dev gcc
sudo apt-get install g++ freeglut3-dev build-essential libx11-dev libxmu-dev libxi-dev libglu1-mesa libglu1-mesa-dev

## Adding GPU Drivers repo

sudo add-apt-repository ppa:graphics-drivers/ppa  
sudo apt update
# Install the compatible GPU drivers if not preinstalled

## Installing Cuda

wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-ubuntu2204.pin  

sudo mv cuda-ubuntu2204.pin /etc/apt/preferences.d/cuda-repository-pin-600  
  
sudo apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/3bf863cc.pub  
  
sudo add-apt-repository "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/ /"  
  
sudo apt-get update  
  
sudo apt install cuda-11-7  

echo 'export PATH=/usr/local/cuda-11.7/bin:$PATH' >> ~/.bashrc  
  
echo 'export LD_LIBRARY_PATH=/usr/local/cuda-11.7/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc  
  
source ~/.bashrc  
  
sudo ldconfig

sudo reboot

## To verify install

nvcc -V

nvidia-smi  

```

### Step 2: Data Prep

The key to any AI project is getting CLEAN DATA.
There are two options to get the data,
#### Record *your voice* using the Piper Recording Studio : https://github.com/rhasspy/piper-recording-studio.git

#### **Pull audio data from YouTube videos** : 

- *Download YT Videos* : Around 1 hr of clips should be good enough
```
cd ~
mkdir dataprep
cd dataprep

python3 -m venv .venv
source .venv/bin/activate

pip install yt-dlp

yt-dlp -x --audio-format wav "YT-URL"

```
- *Cleanup your audio samples* : Piper requires audio samples around 10sec each. Use Audacity to trim clips. When exporting from Audacity, Piper requires the audio in this format:
	- Format: wav
	- Channels: mono
	- Sample Rate: 22050 Hz
- *Remove Silence & Cut up your files* :
```
for file in ./*.wav; do
    ffmpeg -i "$file" -af "silenceremove=stop_periods=-1:stop_duration=3:stop_threshold=-25dB" "./${file%.wav}_nosilence.wav"
done


mkdir wav 

for file in *.wav; do
  ffmpeg -i "$file" -f segment -segment_time 15 -c copy "./wav/split_${file%.*}_%03d.wav"
done
```
-  *Transcribe your audio samples with Whisper* (Using a python script) :
```
pip install git+https://github.com/openai/whisper.git

nano transcribe.py
```
```
import os
import whisper

model = whisper.load_model("base")

audio_dir = "./wav"
output_csv = "./metadata.csv"

audio_files = [f for f in os.listdir(audio_dir) if f.endswith(".wav")]
audio_files.sort()

with open(output_csv, "w") as f:
    for audio_file in audio_files:
        audio_path = os.path.join(audio_dir, audio_file)
        
        result = model.transcribe(audio_path)

        transcription = result["text"].strip()

        file_id = os.path.splitext(audio_file)[0]
        
        f.write(f"{file_id}|{transcription}\n")

print(f"Metadata saved to {output_csv}")
```
```
python3 transcribe.py

deactivate

cd ~/
```

### Step 3: Training Prep

- **Prepare the Training Env** :  11.8(Nvidia 40xx)
	*Note*: For Nvidia 40 series, also follow this: https://github.com/rhasspy/piper/issues/295
```
mkdir training
cd training

git clone https://github.com/rhasspy/piper.git

python3 -m venv .venv
source .venv/bin/activate

python3 -m pip install pip==23.3.1
pip install numpy==1.24.4
pip install torchmetrics==0.11.4

cd piper/src/python

python3 -m pip install --upgrade wheel setuptools

pip3 install -e .

./build_monotonic_align.sh
```
- Process dataset to the format piper requires:
```
python3 -m piper_train.preprocess \
  --language en \
  --input-dir ~/dataprep/ \
  --output-dir ~/training/dataset \
  --dataset-format ljspeech \
  --single-speaker \
  --sample-rate 22050
```
- Download a starting point (checkpoint) : https://huggingface.co/datasets/rhasspy/piper-checkpoints/tree/main/en/en_US/lessac . I would recommend using (lessac) Medium
```
wget https://huggingface.co/datasets/rhasspy/piper-checkpoints/resolve/main/en/en_US/lessac/medium/epoch%3D2164-step%3D1355540.ckpt
```

### Step 4: Training the model

```
python3 -m piper_train \
    --dataset-dir ~/training/dataset/ \
    --accelerator 'gpu' \
    --gpus 1 \
    --batch-size 16 \
    --validation-split 0.0 \
    --num-test-examples 0 \
    --max_epochs 6000 \
    --resume_from_checkpoint "~/training/epoch=2164-step=1355540.ckpt" \
    --checkpoint-epochs 1 \
    --precision 16 \
    --max-phoneme-ids 400 \
    --quality medium 
```

- Pausing and Resuming
	- The training can be interrupted and picked up where it was left off by ctrl-c
	- To resume training, use the same command but change the checkpoint file to the most recent checkpoint file, created under :  `dataset/lightning_logs` 
- Exporting the voice model : After the final epoch is reached, training is done, and model can be exported
```
# Export the model

python3 -m piper_train.export_onnx \
    "~/training/dataset/lightning_logs/version_0/checkpoints/epoch=5999-step=xxxxxx.ckpt" \
    ~/output/directory/voicemodel.onnx
```
```
# Copy the training json file to your model file directory

cp ~/training/dataset/config.json ~/output/directory/voicemodel.onnx.json
```

### Testing the Voice Model

```
pip install piper-tts

echo "Completed, the training is" | piper -m voicename.onnx --output_file test.wav
```

### Using the Voice Model for HA voice assistant

- The Voice Model can be transferred to Home Assistant using the SAMBA share plugin.
- Inside the `share` folder, Create a new folder : `piper` , and paste the `voicemodel.onnx` & `voicemodel.onnx.json` files inside this folder.
- To edit the name this voice model shows as inside HA, edit the `dataset` & `quality` inside the `voicemodel.onnx.json` file. 
- After restarting Home Assistant, this voice model should be ready for use, and can be selected by editing the Voice Assistant settings, and under Text-to-speech, a new language should be created (English), and under Voice the new Voice Model should be present.
- It is also possible to change the system prompt of the LLM in its settings to match the persona of who's voice was cloned.