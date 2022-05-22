#!/bin/bash

#
# Copyright (C) 2022 GeoPD <geoemmanuelpd2001@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# User
GIT_USER="Mishrahpp"

# Email
GIT_EMAIL="mishrahpp2005@gmail.com"

# Local manifest
LOCAL_MANIFEST=https://${TOKEN}@github.com/Mishrahpp/local_manifests

# ROM Manifest and Branch
rom() {
	case "${NAME}" in
		"AOSPA-12") MANIFEST=https://github.com/AOSPA/manifest.git BRANCH=sapphire
		;;
		"AEX-12") MANIFEST=https://github.com/AospExtended/manifest.git BRANCH=12.1.x
		;;
		"Crdroid-12") MANIFEST=https://github.com/crdroidandroid/android.git BRANCH=12.1
		;;
		"dot12.1") MANIFEST=https://github.com/DotOS/manifest.git BRANCH=dot12.1
		;;
		"Evox-12") MANIFEST=https://github.com/Evolution-X/manifest.git BRANCH=snow
		;;
		*) echo "Setup Rom manifest and branch name in case function"
 		exit 1
 		;;
	esac
}

# Build command for rom
build_command() {
	case "${NAME}" in
		"AOSPA-12") lunch aospa_spes-user && m otapackage -j20
		;;
		"AEX-12") lunch aosp_spes-user && m aex -j20
		;;
		"Crdroid-12") lunch lineage_spes-user && m bacon -j20
		;;
		"dot12.1") lunch dot_spes-user && m bacon -j20
		;;
		"Evox-12") lunch evolution_spes-user && m evolution -j20
		;;
		*) echo "Build commands need to be added!"
		exit 1
		;;
	esac
}

# Export tree paths
tree_path() {
	# Device,vendor & kernel Tree paths
	DEVICE_TREE=device/xiaomi/spes
	VENDOR_TREE=vendor/xiaomi/spes
	KERNEL_TREE=kernel/xiaomi/spes
}

# Build post-gen variables (optional)
lazy_build_post_var() {
	LAZY_BUILD_POST=true
	ANDROID_VERSION="Android 12L"
	RELEASE_TYPE="Test"
	DEV=GeoPD
	TG_LINK=https://t.me/mysto_o
	GRP_LIN="@mystohub"
	DEVICE2=daisa #Since I do unified builds for daisy&sakura
}

# Clone needed misc scripts and ssh priv keys (optional)
#clone_file() {
#	rclone copy brrbrr:scripts/setup_script.sh /tmp/rom
#	rclone copy brrbrr:ssh/ssh_ci /tmp/rom
#}

# Setup build dir
build_dir() {
	mkdir -p /tmp/rom
	cd /tmp/rom
}

# Git configuration values
git_setup() {
	git config --global user.name $GIT_USER
	git config --global user.email $GIT_EMAIL

	# Establish Git cookies
	echo "${GIT_COOKIES}" > ~/git_cookies.sh
	bash ~/git_cookies.sh
}

# SSH configuration using priv key
#ssh_authenticate() {
#	sudo chmod 0600 /tmp/rom/ssh_ci
#	sudo mkdir ~/.ssh && sudo chmod 0700 ~/.ssh
#	eval `ssh-agent -s` && ssh-add /tmp/rom/ssh_ci
#	ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts
#}

# Repo sync and additional configurations
build_configuration() {
	repo init --depth=1 --no-repo-verify -u $MANIFEST  -b $BRANCH -g default,-mips,-darwin,-notdefault
	git clone $LOCAL_MANIFEST -b $NAME .repo/local_manifests
	repo sync -c --no-clone-bundle --no-tags --optimized-fetch --prune --force-sync -j13
	source setup_script.sh
	source build/envsetup.sh
}

# Export time, time format for telegram messages
time_sec() {
	export $1=$(date +"%s")
}

time_diff() {
	export $1=$(($3 - $2))
}

# Branch name & Head commit sha for ease of tracking
commit_sha() {
	tree_path
	for repo in ${DEVICE_TREE} ${VENDOR_TREE} ${KERNEL_TREE}
	do
		printf "[$(echo $repo | cut -d'/' -f1 )/$(git -C ./$repo/.git rev-parse --short=10 HEAD)]"
	done
}

# Setup ccache
ccache_configuration() {
	export CCACHE_DIR=/tmp/ccache
	export CCACHE_EXEC=$(which ccache)
	export USE_CCACHE=1
	export CCACHE_DEPEND=true
	export CCACHE_FILECLONE=true
	export CCACHE_LIMIT_MULTIPLE=0.9
	export CCACHE_MAXSIZE=50G
	export CCACHE_NOCOMPRESS=true
	export CCACHE_NOHASHDIR=1
	ccache -z
}

# Setup TG message and build posts
telegram_message() {
	curl -s -X POST "https://api.telegram.org/bot${BOTTOKEN}/sendMessage" -d chat_id="${CHATID}" \
	-d "parse_mode=Markdown" \
	-d text="$1"
}

telegram_build() {
	curl --progress-bar -F document=@"$1" "https://api.telegram.org/bot${BOTTOKEN}/sendDocument" \
	-F chat_id="${CHATID}" \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=Markdown" \
	-F caption="$2"
}

telegram_build_post() {
	curl -s -F "photo=@$1" "https://api.telegram.org/bot${BOTTOKEN}/sendPhoto" \
	-F chat_id="${CHATID}" \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=Markdown" \
	-F caption="$2"
}

# Send Telegram posts for sync finished, build finished and error logs
telegram_post_sync() {
	telegram_message "
	*🌟 $NAME Build Triggered 🌟*
	*Date:* \`$(date +"%d-%m-%Y %T")\`
	*✅ Sync finished after $((SDIFF / 60)) minute(s) and $((SDIFF % 60)) seconds*"  &> /dev/null
}

telegram_post_build() {
	telegram_message "
	*✅ Build finished after $(($BDIFF / 3600)) hour(s) and $(($BDIFF % 3600 / 60)) minute(s) and $(($BDIFF % 60)) seconds*

	*ROM:* \`${ZIPNAME}\`
	*MD5 Checksum:* \`${MD5CHECK}\`
	*Download Link:* [Tdrive](${DWD})
	*Size:* \`${ZIPSIZE}\`

	*Commit SHA:* \`$(commit_sha)\`

	*Date:*  \`$(date +"%d-%m-%Y %T")\`" &> /dev/null
}

telegram_post_error() {
	telegram_build ${ERROR_LOG} "
	*❌ Build failed to compile after $(($BDIFF / 3600)) hour(s) and $(($BDIFF % 3600 / 60)) minute(s) and $(($BDIFF % 60)) seconds*
	_Date:  $(date +"%d-%m-%Y %T")_" &> /dev/null
}

# Sorting final zip ( commonized considering ota zips, .md5sum etc with similiar names  in diff roms)
compiled_zip() {
	ZIP=$(find $(pwd)/out/target/product/${T_DEVICE}/ -maxdepth 1 -name "*${T_DEVICE}*.zip" | perl -e 'print sort { length($b) <=> length($a) } <>' | head -n 1)
	ZIPNAME=$(basename ${ZIP})
	ZIPSIZE=$(du -sh ${ZIP} |  awk '{print $1}')
	MD5CHECK=$(md5sum ${ZIP} | cut -d' ' -f1)
	echo "${ZIP}"
}

# Generate changelog of past 7 days
generate_changelog() {
	CHANGELOG=$(pwd)/changelog_gen.txt
	touch ${CHANGELOG}
	echo "Generated Date: $(date)" >> ${CHANGELOG}

	for i in $(seq 7);
	do
		after_date=`date --date="$i days ago" +%F`
		until_date=`date --date="$(expr ${i} - 1) days ago" +%F`
		echo "====================" >> ${CHANGELOG}
		echo "     $until_date    " >> ${CHANGELOG}
		echo "====================" >> ${CHANGELOG}
		while read path; do
			git_log=`git --git-dir ./${path}/.git log --after=$after_date --until=$until_date --format=tformat:"%s [%an]"`
			if [[ ! -z "${git_log}" ]]; then
			echo "* ${path}" >> ${CHANGELOG}
			echo "${git_log}" >> ${CHANGELOG}
			echo "" >> ${CHANGELOG}
			fi
		done < ./.repo/project.list
	done
}

# Generate telegraph post of changelog
telegraph_post() {
	generate_changelog
	sed -i "s/\"/'/g" ${CHANGELOG}
	curl -X POST \
		-H 'Content-Type: application/json' \
		-d '{
			"access_token": "'${TGP_TOKEN}'",
			"title": "Source Changelogs",
			"author_name":"geopd",
			"content": [{"tag":"p","children":["'"$(cat ${CHANGELOG})"'"]}],
			"return_content":"true"
		}' \
		https://api.telegra.ph/createPage | cut -d'"' -f12
}

# Aah yes! Generate a build post that's similiar to normal official posts
# Now no more pain of making posts; just forward and Enjoy.
lazy_build_post() {
	rclone copy brrbrr:images/ $(pwd)
	if [ -f $(pwd)/${NAME}* ]; then
		POST_IMAGE=$(pwd)/${NAME}*
	else
		POST_IMAGE=$(pwd)/mystohub*
	fi
	T_NAME=$(echo ${NAME,,}| cut -d'-' -f1)

	telegram_build_post ${POST_IMAGE} "
	*#${T_NAME} #ROM #$(echo ${ANDROID_VERSION,,} | tr -d ' ') #${T_DEVICE,,} #${DEVICE2,,}
	$(echo ${ZIPNAME^^}| cut -d'-' -f1) | ${ANDROID_VERSION^}
	Updated:* \`$(date +"%d-%B-%Y")\`
	*By:* [${DEV}](${TG_LINK})

	*▪️ Downloads:* [Vanilla](${DWD}) *(${ZIPSIZE})*
	*▪️ Changelogs:* [Source Changelogs]($(echo $(telegraph_post) | tr -d '\\'))
	*▪️ ROM:* \`${ZIPNAME}\`
	*▪️ MD5 Checksum:* \`${MD5CHECK}\`

	*Notes:*
	• ${ANDROID_VERSION} ${RELEASE_TYPE} Release.

	*Build Info:*
	• *✅ Build finished after $(($BDIFF / 3600)) hrs : $(($BDIFF % 3600 / 60)) mins : $(($BDIFF % 60)) secs*
	• *Commit SHA:* \`$(commit_sha)\`

	*Follow* ${GRP_LIN}
	*Join* ${GRP_LIN}
	*Date:*  \`$(date +"%d-%m-%Y %T")\`" &> /dev/null
}

# Post Build finished with Time,duration,md5,size&Tdrive link OR post build_error&trimmed build.log in TG
telegram_post(){
	if [ -f $(pwd)/out/target/product/${T_DEVICE}/${ZIPNAME} ]; then
		rclone copy ${ZIP} spes:rom -P
		DWD=${TDRIVE}${ZIPNAME}
		if [[ $GIT_USER = GeoPD && $LAZY_BUILD_POST = true ]]; then
			lazy_build_post
		else
			telegram_post_build
		fi
	else
		echo "CHECK BUILD LOG" >> $(pwd)/out/build_error
		ERROR_LOG=$(pwd)/out/build_error
		telegram_post_error
	fi
}


# Compile moments! Yay!
compile_moments() {
	build_dir
	git_setup
	if [ $GIT_USER = GeoPD ]; then
		clone_file
		lazy_build_post_var
	fi
	ssh_authenticate
	time_sec SYNC_START
	rom
	build_configuration
	ccache_configuration
	time_sec SYNC_END
	time_diff SDIFF SYNC_START SYNC_END
	telegram_post_sync
	time_sec BUILD_START
	build_command
	time_sec BUILD_END
	time_diff BDIFF BUILD_START BUILD_END
	compiled_zip
	telegram_post
	ccache -s
}

compile_moments
