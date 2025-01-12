#!/bin/bash

cd ~/Developer/sanyamc-blog

rsync -av --delete "~/Documents/Obsidian Vault/Posts/" "~/Developer/sanyamc-blog/content/post/"

read -p "Enter commit message: " message

hugo

git add .
git commit -m "$message"
git push origin main

printf "\n Website Deployed! \n"