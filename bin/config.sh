#!/usr/bin/env bash
# Manage configurations for the ForgeRock platform. Copies configurations in git to the Docker/ folder
set -oe pipefail

## Start of arg parsing - originally generated by argbash.io
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
	local first_option all_short_options='pch'
	first_option="${1:0:1}"
	test "$all_short_options" = "${all_short_options/$first_option/}" && return 1 || return 0
}

# THE DEFAULTS INITIALIZATION - POSITIONALS
_positionals=()
# THE DEFAULTS INITIALIZATION - OPTIONALS
_arg_component="all"

_arg_profile="${CDK_PROFILE:-cdk}"


print_help()
{
	printf '%s\n' "manage ForgeRock platform configurations"
	printf 'Usage: %s [-p|--profile <arg>] [-c|--component <arg>] [-h|--help] <operation>\n' "$0"
	printf '\t%s\n' "<operation>: operation is one of init - to copy initial configuration, diff - to run a diff command, export - export config from running instance, save - save to git, restore - restore git (abandon changes), sync - export and save"
	printf '\t%s\n' "-c, --component: Select component - am, amster, idm, ig or all  (default: 'all')"
	printf '\t%s\n' "-p, --profile: Select configuration source (default: 'cdk')"
	printf '\t%s\n' "-h, --help: Prints help"
	printf '\n%s\n' "example to copy idm files: config.sh -c idm -p cdk init"
}


parse_commandline()
{
	_positionals_count=0
	while test $# -gt 0
	do
		_key="$1"
		case "$_key" in
			-c|--component)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				_arg_component="$2"
				shift
				;;
			--component=*)
				_arg_component="${_key##--product=}"
				;;
			-c*)
				_arg_component="${_key##-p}"
				;;
			-p|--profile)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				_arg_profile="$2"
				shift
				;;
			--profile=*)
				_arg_profile="${_key##--config=}"
				;;
			-p*)
				_arg_profile="${_key##-c}"
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

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || die "Couldn't determine the script's running directory, which probably matters, bailing out" 2

# End of arg parsing



# Copy the product config $1 to the docker directory.
init_config()
{
	echo "cp -r ${PROFILE_ROOT}/$1" "$DOCKER_ROOT"
    cp -r "${PROFILE_ROOT}/$1" "$DOCKER_ROOT"
}

# Show the differences between the source configuration and the current Docker configuration
# Ignore dot files, shell scripts and the Dockerfile
# $1 - the product to diff
diff_config()
{
	for p in "${COMPONENTS[@]}"; do
		echo "diff  -u --recursive ${PROFILE_ROOT}/$p $DOCKER_ROOT/$p"
		diff -u --recursive -x ".*" -x "Dockerfile" -x "*.sh" "${PROFILE_ROOT}/$p" "$DOCKER_ROOT/$p" || true
	done
}

# Export out of the running instance to the docker folder
export_config(){
	for p in "${COMPONENTS[@]}"; do
	   # We dont support export for all products just yet - so need to case them
	   case $p in
		idm)
			echo "Exporting IDM configuration"
			rm -fr  "$DOCKER_ROOT/idm/conf"
			kubectl cp idm-0:/opt/openidm/conf "$DOCKER_ROOT/idm/conf"
			;;
		amster)
			echo "Finding the amster pod"
			pod=`kubectl get pod -l app=amster -o jsonpath='{.items[0].metadata.name}'`
			echo "Executing amster export from $pod"
			kubectl exec $pod -it /opt/amster/export.sh
			rm -fr "$DOCKER_ROOT/amster/config"
			kubectl cp "$pod":/var/tmp/amster "$DOCKER_ROOT/amster/config"
			;;
		am)
			echo "AM file based configuration not supported yet"
			;;
		*)
			echo "Export not supported for $p"
		esac
	done
}

# Save the configuration in the docker folder back to the git source
save_config()
{
		for p in "${COMPONENTS[@]}"; do
	   # We dont support export for all products just yet - so need to case them
	   case $p in
		idm)
			# clean existing files
			rm -fr  "$PROFILE_ROOT/idm/conf"
			cp -R "$DOCKER_ROOT/idm/conf"  "$PROFILE_ROOT/idm"
			;;
		amster)
			# Clean any existing files
			rm -fr "$PROFILE_ROOT/amster/config"
			cp -R "$DOCKER_ROOT/amster/config"  "$PROFILE_ROOT/amster/config"
			;;
		*)
			echo "Save not supported for $p"
		esac
	done
}

# The calculated roots below are more correct- but they lead to longer file names being displayed.
# If the user runs this from the root directory the file names get easier.
#PROFILE_ROOT="$script_dir/../config/$_arg_profile"
#DOCKER_ROOT="$script_dir/../docker"

# Instead we chdir to the script root/..
cd "$script_dir/.."
PROFILE_ROOT="config/$_arg_profile"
DOCKER_ROOT="docker"


# TODO: Right now we only handle idm and ig configs
if [ "$_arg_component" == "all" ]; then
	COMPONENTS=(idm ig amster)
else
COMPONENTS=( "$_arg_component" )
fi


case "$_arg_operation" in
init)
	for p in "${COMPONENTS[@]}"; do
		init_config "$p"
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
	git restore "$PROFILE_ROOT"
	;;
*)
	echo "Unknown command $_arg_operation"
esac
