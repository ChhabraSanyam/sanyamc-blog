---
title: Building a Blog Website for free
description: Making & hosting a website for free using a static site generator
date: 2025-01-10
categories:
  - Website
image: cover.jpg
---

> # Introduction

I am going to build a free website using a static site generator *HUGO* and hosting it on *Cloudflare pages*.
The *workflow* will be like this: The posts will be made in markdown format (using Obsidian), then it will be converted into html (using Hugo), then it will be pushed to a github repository, from where a free static hosting provider (cloudflare pages) will pull the public directory files, and host the website.
I will also provide a bash script to automate deploying the website.
*Note* : The CLI commands mentioned will be valid for linux, macos & wsl.


# Step 1 : Build a static site using HUGO

- Install Dependencies : [Git](https://github.com/git-guides/install-git) & [Go](https://go.dev/dl/)
- Install [Hugo](https://gohugo.io/installation/)
- Create a new site :
	`Verify if Hugo works`
```
hugo version
```
	Generate a new site directory (First navigate to a directory where site should be stored)
```
hugo new site {websitename}
cd {websitename}
```

- Initialize a git repository (Make sure you are in your Hugo website directory)
```
git init

# Set global username and email parameters for git

git config --global user.name "{Your Name}"
git config --global user.email "{your.email@example.com}"
```

- Install a Hugo theme : Find a [theme](https://themes.gohugo.io/)
	Follow the theme instructions on how to download. The BEST option is to install as a git submodule. I am using the theme *stack*
```
git submodule add https://github.com/{theme_repo} themes/{theme_name}
```
	Once downloaded it should be in your Hugo themes folder

- Adjust Hugo Theme settings : 
	- Every theme has a different setup configuration. Refer to the theme's page for specific documentation.
	- To set the theme, edit the *hugo.toml* present in the site directory, and add `theme = "{theme_folder_name}"`. Also edit the other settings in the *toml* file accordingly.
	- Most themes will also have an example configuration or an *exampleSite* folder. Copy over the contents to the Hugo site directory. This is usually the best way to make sure Hugo works well and out of the box.
	- The exampleSite should also contain sample posts, which should be used for reference while creating new posts. The example posts will be present in a "*post/posts*" folder, under the *content* folder, in the site directory.

- Test Hugo site
```
hugo server -t {themename}
```
	Visit the local url generated to see the look of the site

# Step 2 : Push the Website code to GitHub

- Create a new private repository on Github with the name for your website 
- Add your SSH public key to your Github account, to push the site to the remote repo just created. Official Documentation [here](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)
- Push site to GitHub : 
	1. Navigate to the Hugo site directory
	2. Connect the remote repo to the local repo
```
git remote add origin git@github.com:{github_username}/{repository_name}.git
```
	3. Push site code
```
git add .
git commit -m "{commit message}"
git push -u origin main
```

# Step 3 : Host the site using Cloudflare Pages

- SignIn/SignUp at [Cloudflare Pages](https://pages.cloudflare.com/) 
- Select Pages, and connect to github account
- Select the Hugo site repository and begin setup
- Change the project name to desired site name, and select the production branch as main
- Under *Build Settings*, change the *Framework preset* to *Hugo*
- Also add an *Environment Variable* : `HUGO_VERSION = v{your.hugo.version}+extended` 
	(use command `hugo version` in terminal to find your Hugo version)
- Finally, *Save and Deploy*. Let it deploy the site, then *Continue to project*. Now you can *Visit* the site. It should look exactly the same as it did when deployed locally.
- Some other settings to change in the project would be, if you want to add *Custom domains*, or turn on web analytics. You can also adjust other *Settings* as per requirement.
- By default, Cloudflare Pages will automatically Deploy the newest version of the site, whenever changes are made and pushed to the GitHub site repository.

# Step 4 : Creating posts in Obsidian

- Get Obsidian [here](https://obsidian.md/), or any other markdown editor will work aswell.
- Create a vault in Obsidian (if not done already), to store markdown files, and make a folder called *'Posts'*, where the blog posts will be stored.
- Also, right click on the *Posts* folder and reveal its location. This directory will be required later.
	*Note* :  Any notes/posts can be created in obsidian, but only ones moved to the *Posts* folder will be published.
- The posts in the "*Posts*" folder should be made following the layout of the "post/posts" folder under *content* directory of the site, as per the Theme used for proper working. Other assets (such as images) should also be stored as per the Theme's layout. *Use the exampleSite for reference*.
- Some settings you should change in Obsidian would be :
	Turn off *Use Wikilinks* & set *New link format* to relative path to file
	Also set *Default location for new attachments*, according to the Theme
- To create new posts, take reference from sample post. It often provides guides to syntax and layout structure for the posts. 
- Also add some *Frontmatter* in the beginning of file. Example :
```
---
title: blogtitle
date: 20245-1-10
draft: false
tags:
  - tag1
  - tag2
---
```
	A Template can also be created in Obsidian to create each new post with frontmatter automatically.
- After making the Posts, *rsync* command will be used to sync the contents of the posts folder in Obsidian and the Hugo site.
```
rsync -av --delete "/path/to/obsidian/posts/" "/path/to/hugo/posts/"
```

*Note* : A lot of useful plugins are available for Obsidian to make Markdown easier. A few I would recommend are : *Editing toolbar*, *Paste URL into selection*, *Templater*


# The Workflow

All we have to do is, create posts in the Posts folder of the Obsidian Vault, in the format according to the Hugo Theme. Then run this automatic deployment script below.

*Make sure to change the paths in the script according to your configuration.*
```bash
#!/bin/bash

cd "/path/to/site/directory"

read -p "Enter commit message: " message

rsync -av --delete "/path/to/obsidian/posts/" "/path/to/hugo/posts/"

git add .
git commit -m "$message"
git push origin main

printf "\n \e[32m	Webiste Deployed!	\e[39m \n"
```
Just copy this and create a bash script (with extension '.sh'), in your site directory.

To Deploy changes in the site, to Cloudflare Pages, just run this bash script , `sudo bash {script_name}.sh`
