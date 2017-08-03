#!/usr/bin/env bash

padding () {
	local char=" "
	if [ "$#" -gt "1" ]; then
		local char=${1:-$char}
		local count=${2:-"1"}
	elif [ "$#" -eq "1" ]; then
		local count=${1:-"1"}
	fi
	if [ "$char" != " " ]; then
		eval printf "%0.1s" "${char}"{1..${count}}
	else
		printf "%*s\n" "$count" "$char"
	fi
}

log () {
	local msg=$1
	if [ "$#" -gt "1" ]; then
		local num=${2}
		local pad_char=${3}
		msg="$(padding $pad_char $num)$msg"
	fi
	printf "%s\n" "$msg"
}

render_template () {
	local vars=$@
	printf "%s" "$vars"
}

# Markdown specific
h1 () {
	local title=${1:-"H1"}
	local template="${title}
$(padding = ${#title})

"
	render_template "$template"
}
h2 () {
	local title=${1:-"H2"}
	local template="${title}
$(padding - ${#title})

"
	render_template "$template"
}

# Directory structure generation
generate_readme () {
	local project_name=$1
	local description=${2:-"Ansible project"}
	local readme_template="$(h1 ${project_name})

${description}

$(h2 "Requirements")

Project requirements

$(h2 "Variables")

* variable1
* variable2

$(h2 Example)

EXAMPLE

$(h2 "License")

LICENSE

$(h2 "Author Information")

AUTHOR_NAME
"
	render_template "$readme_template"
}

generate_main_yml () {
	local template="---
# file: $(basename $(pwd) )/main.yml
# created-on: $(date +'%Y-%m-%d')
"
	render_template "$template"
}

generate_role () {
	local role_name=$1
	local directories="tasks handlers templates files vars defaults"
	local exclude_generate="templates files"
	local roles_dir=$(pwd)
	
	log "> Generating role $role_name" 4 "="
	mkdir -p $role_name/
	cd $role_name
	
	local cwd=$(pwd)
	for d in $directories; do
		log "> Creating roles/$role_name/$d" 6 "="
		mkdir -p $d
		if [[ "$exclude_generate" =~ "$d" ]]; then
			log "> Not generating main.yml for $d" 6 "="
		else
			cd $d
			log "> Generating main.yml for $d" 6 "="
			generate_main_yml > main.yml
			cd $cwd
		fi
	done
	log "> Generating README.md for $role_name" 6 "="
	generate_readme "$role_name" "Ansible Role" > README.md
	cd $roles_dir
}

generate_playbook () {
	local project_name=$1
	shift
	local roles=($@)
	local cwd=$(pwd)
	local playbook_template="---
# created-on: $(date +'%Y-%m-%d')
- hosts: all
	roles:
"
	log "> Generating roles [$roles]" 2 "="
	cd roles
	for r in "${roles[@]}"; do
		generate_role "$r"
	done
	cd $cwd
	log "> Generating playbook" 2 "="
	printf "%s" "$playbook_template" > site.yml
	for	r in "${roles[@]}"; do
		printf "	- role: %s\n" "$r" >> site.yml
	done
}

generate_structure () {
	local root_dir=$1
	log "> Generating directory tree" 2 "="
	mkdir -p $root_dir/{filter_plugins,roles}
	touch $root_dir/{production_inventory,staging_inventory,testing_inventory}
}

main () {
	local project_name=${1:-"test-playbook"}
	shift
	local roles=${@:-"example"}
	log "Scaffolding project ${project_name} with roles [${roles}]:"
	log ""
	generate_structure $project_name
	cd $project_name
	generate_playbook $project_name $roles
	generate_readme $project_name > README.md
	if [ ! -d ".git" -a $(command -v git) ]; then
		log "> Initializing git repository" 2 "="
		git init .
	fi
}

if [ "$#" -ge "1" ]; then
	main $@
else
	echo "Usage: $(basename $0) PROJECT_NAME [ROLES...]"
	exit 1
fi