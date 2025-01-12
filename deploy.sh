#!/bin/bash

cd ~/Developer/sanyamc-blog

read -p "Enter commit message: " message

rsync -av --delete "/Users/sanyamc/Documents/Obsidian Vault/Posts/" "/Users/sanyamc/Developer/sanyamc-blog/content/post/"

hugo

git add .
git commit -m "$message"
git push origin main

printf "\n \e[32m	Webiste Deployed!	\e[39m"