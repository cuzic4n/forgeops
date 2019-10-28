#!/usr/bin/env bash
# Manage configurations for the ForgeRock platform. Copies configurations in git to the Docker/ folder
#
# Arguments generated using https://argbash.io/
# ARG_OPTIONAL_SINGLE([product],[p],[Select product - am, idm, ig or all ],[all])
# ARG_OPTIONAL_SINGLE([config],[c],[Select configuration source],[cdk])
# ARG_POSITIONAL_SINGLE([operation],[operation: init - copy initial files, diff - to run a diff on source/target, export - export config, save - save to git, restore - restore git, sync - export and save  ])
# ARG_HELP([manage ForgeRock platform configurations],[example to copy idm files: config.sh -p idm -o cp])
# DEFINE_SCRIPT_DIR()_DEFINE_SCRIPT_DIR([],[cd "$(dirname "${BASH_SOURCE[0]}")" && pwd])
# ARGBASH_GO()
# needed because of Argbash --> m4_ignore([
### START OF CODE GENERATED BY Argbash v2.8.1 one line above ###
# Argbash is a bash code generator used to get arguments parsing right.
# Argbash is FREE SOFTWARE, see https://argbash.io for more info
# Generated online by https://argbash.io/generate

# Can't use set -e - because diff exits with non zero
set -oe pipefail

die()
{
	local _ret=$2
	test -n "$_ret" || _ret=1
	test "$_PRINT_HELP" = yes && print_help >&2
	echo "$1" >&2
	exit ${_ret}
}


begins_with_short_option()
{
	local first_option all_short_options='pcoh'
	first_option="${1:0:1}"
	test "$all_short_options" = "${all_short_options/$first_option/}" && return 1 || return 0
}

# THE DEFAULTS INITIALIZATION - POSITIONALS
_positionals=()
# THE DEFAULTS INITIALIZATION - OPTIONALS
_arg_product="all"
_arg_config="cdk"
_arg_overwrite="off"


print_help()
{
	printf '%s\n' "manage ForgeRock platform configurations"
	printf 'Usage: %s [-p|--product <arg>] [-c|--config <arg>] [-o|--(no-)overwrite] [-h|--help] <operation>\n' "$0"
	printf '\t%s\n' "<operation>: operation is one of init - to copy initial configuration, diff - to run a diff on source/target, export - export config, save - save to git, restore - restore git, sync - export and save"
	printf '\t%s\n' "-p, --product: Select product - am, amster, idm, ig or all  (default: 'all')"
	printf '\t%s\n' "-c, --config: Select configuration source (default: 'cdk')"
	printf '\t%s\n' "-h, --help: Prints help"
	printf '\n%s\n' "example to copy idm files: config.sh -p idm -o cp"
}


parse_commandline()
{
	_positionals_count=0
	while test $# -gt 0
	do
		_key="$1"
		case "$_key" in
			-p|--product)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				_arg_product="$2"
				shift
				;;
			--product=*)
				_arg_product="${_key##--product=}"
				;;
			-p*)
				_arg_product="${_key##-p}"
				;;
			-c|--config)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				_arg_config="$2"
				shift
				;;
			--config=*)
				_arg_config="${_key##--config=}"
				;;
			-c*)
				_arg_config="${_key##-c}"
				;;
			-h|--help)
				print_help
				exit 0
				;;
			-h*)
				print_help
				exit 0
				;;
			*)
				_last_positional="$1"
				_positionals+=("$_last_positional")
				_positionals_count=$((_positionals_count + 1))
				;;
		esac
		shift
	done
}


handle_passed_args_count()
{
	local _required_args_string="'operation'"
	test "${_positionals_count}" -ge 1 || _PRINT_HELP=yes die "FATAL ERROR: Not enough positional arguments - we require exactly 1 (namely: $_required_args_string), but got only ${_positionals_count}." 1
	test "${_positionals_count}" -le 1 || _PRINT_HELP=yes die "FATAL ERROR: There were spurious positional arguments --- we expect exactly 1 (namely: $_required_args_string), but got ${_positionals_count} (the last one was: '${_last_positional}')." 1
}


assign_positional_args()
{
	local _positional_name _shift_for=$1
	_positional_names="_arg_operation "

	shift "$_shift_for"
	for _positional_name in ${_positional_names}
	do
		test $# -gt 0 || break
		eval "$_positional_name=\${1}" || die "Error during argument parsing, possibly an Argbash bug." 1
		shift
	done
}

parse_commandline "$@"
handle_passed_args_count
assign_positional_args 1 "${_positionals[@]}"

# OTHER STUFF GENERATED BY Argbash
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || die "Couldn't determine the script's running directory, which probably matters, bailing out" 2

### END OF CODE GENERATED BY Argbash (sortof) ### ])
# [ <-- needed because of Argbash

# Copy the product config $1 to the docker directory.
copy_config()
{
    cp -r "${CONFIG_ROOT}/$1" "$DOCKER_ROOT"
}

# Show the differences between the source configuration and the current Docker configuration
# Ignore dot files, shell scripts and the Dockerfile
# $1 - the product to diff
diff_config()
{
	for p in "${PRODUCTS[@]}"; do
		echo "diff ${CONFIG_ROOT}/$p $DOCKER_ROOT/$p"
		diff -u --recursive -x ".*" -x "Dockerfile" -x "*.sh" "${CONFIG_ROOT}/$p" "$DOCKER_ROOT/$p" || true
	done
}

# Export out of the running instance to the docker folder
export_config(){
	for p in "${PRODUCTS[@]}"; do
	   # We dont support export for all products just yet - so need to case them
	   case $p in
		idm)
			kubectl cp idm-0:/opt/openidm/conf "$DOCKER_ROOT/idm/conf"
			;;
		*)
			echo "Export not supported for $p"
		esac
	done
}

# Save the configuration in the docker folder back to the git source
save_config()
{
		for p in "${PRODUCTS[@]}"; do
	   # We dont support export for all products just yet - so need to case them
	   case $p in
		idm)
			cp -R "$DOCKER_ROOT/idm/conf"  "$CONFIG_ROOT/idm"
			;;
		*)
			echo "Save not supported for $p"
		esac
	done
}

# The calculated roots below are more correct- but they lead to longer file names being displayed.
# If the user runs this from the root directory the file names get easier.
#CONFIG_ROOT="$script_dir/../config/$_arg_config"
#DOCKER_ROOT="$script_dir/../docker"

# Instead we chdir to the script root/..
cd "$script_dir/.."
CONFIG_ROOT="config/$_arg_config"
DOCKER_ROOT="docker"


# TODO: Right now we only handle idm and ig configs
if [ "$_arg_product" == "all" ]; then
	PRODUCTS=(idm ig amster)
else
PRODUCTS=( "$_arg_product" )
fi


case "$_arg_operation" in
init)
	for p in "${PRODUCTS[@]}"; do
		copy_config $p
	done
	;;
diff)
	diff_config
	;;
export)
	export_config
	;;
save)
	save_config
	;;
sync)
	export_config
	save_config
	;;
restore)
	git restore "$CONFIG_ROOT"
	;;
*)
	echo "Unknown command $_arg_operation"
esac

# ] <-- needed because of Argbash