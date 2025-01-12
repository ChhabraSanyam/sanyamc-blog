#!/bin/bash

cd ~/Developer/sanyamc-blog

read -p "Enter commit message: " message

rsync -av --delete "/Users/sanyamc/Documents/Obsidian Vault/Posts/" "/Users/sanyamc/Developer/sanyamc-blog/content/post/"

hugo

git add .
git commit -m "$message"
git push origin main

printf "\n Website Deployed! \n"