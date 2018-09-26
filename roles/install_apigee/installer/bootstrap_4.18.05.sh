#! /bin/bash
# !!! THIS IS A GENERATED FILE - DO NOT EDIT !!!
#
# BOOTSTRAP_VERSION=Apigee bootstrap 1.0
# BUILD_NUMBER=379
# BUILD_DATE=2018.04.24,01:34
# GIT_BRANCH=origin/OPDK_1805
# GIT_COMMIT=95a41f59bfff0e4a11ec439f765f47091dfa0b9d
#
# SYNOPSIS: bootstrap.sh [VAR=VALUE ...]
#
# FLAGS: none
#
# ARGUMENTS: optional, VAR=VALUE
#
# DESCRIPTION:
# run preinstall tasks for edge private cloud.
# should culminate in the installation of apigee-service.
#
# * check that host's os and distro are supported.
# * check for perl, and install if necessary.
# * check java, and install if necessary.
# * check that selinux is absent or disabled.
# * check for proper credentials and/or license (TBD).
# * configure yum or zypper as appropriate per platform,
#   to download from apigee repo servers.
# * install apigee-service.
#
# NOTE: all variables are presumed to be permissively urlencoded when
# they are sourced in.  that is, anything not containing a % sign is
# taken literally.
#
# environment variables: see set_production_defaults.
#
# EXIT_STATUS: 0 on success, non-0 on failure.
#

# print debugging message, only if $TEST_DEBUG is true.
DBG()
{
	$TEST_DEBUG && echo 1>&2 "# $*"
	return 0
}

# print a section header to stderr.
Header()
{
	echo 1>&2 ""
	echo 1>&2 "=== $*"
}

#
# star out the password in a command line containing a URL.
# print the resulting line.
# the URL is expected to be of the form
# anything ://USER:PASSWORD@ anything.
# we don't want to display the password.
#
urlhack()
{
	sed -e 's,\(://[^@/:]*\):[^@/:]*@,\1:***@,' <<< "$*"
}

#
# verbosely run the given command.
# HACK: star out the password in a URL, before echoing.
#
vrun()
{
	echo 1>&2 "+ $(urlhack "$*")"
	"$@"
}

# print a message to stderr, prefixed by program name.
notice()
{
	echo 1>&2 "$PROGNAME: $*"
}

# print an error message to stderr.
errmsg()
{
	notice "Error: $*"
	return 1
}

# ignore an error and return true
ignore()
{
	echo 1>&2 "(error can be ignored)"
}

#
# given the raw release name (as arguments), canonicalize it and print.
#
# NOTE: this function is a copy of the function of the same name
# in apigee-service/lib/service-functions.sh .
#
_canon_distro()
{
	sed -e 's/ release //' \
	    -e 's/ *(.*)//' \
	    -e 'y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/' \
	    -e 's/suse linux enterprise server /sles/' \
	    -e 's/red *hat *enterprise *linux *\(server\)*/rhel/' \
	    -e 's/ *$//' \
	    -e 's/ /_/g'<<< "$*"
}

#
# print the raw release message for from the current host.
#
# NOTE: this function is a copy of the function of the same name
# in apigee-service/lib/service-functions.sh .
#
# the etc argument is optional, used for testing.
# shellcheck disable=SC2120
_release_message()
{
	local etc=${1:-/etc}
	local f

	# if /etc/redhat-release is there, take it.
	for f in "$etc"/{redhat,system,SuSE}-release; do
		if [[ -f "$f" ]]; then
			cat "$f" && return 0
		fi
	done

	# otherwise scrounge for other similarly named files.
	# shellcheck disable=SC2045
	for f in $(ls -- "$etc"/*-release 2>/dev/null); do
		case $f in
		*/os-release|*/lsb-release) continue ;;
		*) cat "$f" && return 0 ;;
		esac
	done

	# nothing found
	return 1
}

#
# return the canonicalized distro name from the current host.
#
# NOTE: this function is a copy of the function of the same name
# in apigee-service/lib/service-functions.sh .
#
# the msg argument is optional, used for testing.
# shellcheck disable=SC2120
_get_distro()
{
	local msg=${1:-$(_release_message)}
	: "${msg:=Unknown_distro}"
	_canon_distro "$msg"
}

#
# check the host machine's distro name, return true if supported.
#
# shellcheck disable=SC2120
# the DISTRO argument is optional, used for testing.
distro_check()
{
	local DISTRO
	DISTRO=${1:-${TEST_DISTRO:-$(_get_distro)}}
	Header "Checking distro:"
	local vers
	vers=$(sed -n -e 's/^[^0-9]*\([0-9][0-9.]*\).*/\1/p' <<< "$DISTRO")
	local v=($(tr '.' ' ' <<< "$vers"))
	v+=(0 0)
	local major=${v[0]} minor=${v[1]}
	local ok=false

	case $DISTRO in
	amazon_linux_ami*)
		ok=true ;;
	rh*|redhat*|centos*|oracle_linux*)
		((6 <= major && major <= 7)) && ok=true ;;
	sles*)
		((11 <= major && major <= 12)) && ok=true ;;
	*)
		ok=false ;;
	esac

	if ! $ok; then
		errmsg "distro=$DISTRO (major=$major minor=$minor) is not supported"
	else
		DBG "OK - distro=$DISTRO is supported"
	fi
}

# check the host machine's architecture, return true if supported.
# the arch argument is optional, used for testing.
# shellcheck disable=SC2120
arch_check()
{
	Header "Checking architecture:"
	local arch
	arch=${1:-$(uname -m)}
	case $arch in
	x86_64) DBG "OK - arch=$arch is supported" ;;
	*) errmsg "architecture=$arch is not supported" ;;
	esac
}

# check the host machine's OS, return true if supported.
# the OS argument is optional, used for testing.
# shellcheck disable=SC2120
os_check()
{
	Header "Checking OS:"
	local OS
	OS=${1:-$(uname -s)}
	case $OS in
	Linux|Darwin) DBG "OK - OS=$OS is supported" ;;
	*) errmsg "OS=$OS is not supported" ;;
	esac
}

# check that selinux is not enabled
# the status argument is optional, used for testing.
# shellcheck disable=SC2120
selinux_check()
{
	Header "Checking SELinux status"
	local status
	status=${1:-$(/usr/sbin/getenforce 2>/dev/null)}
	status=$(tr 'A-Z' 'a-z' <<< "$status")
	case X$status in
	Xdisabled|Xpermissive|X)
		DBG "OK - SELinux status=$status"
		return 0
		;;
	*)
		errmsg "SELinux must be disabled first"
		return 1
		;;
	esac
}

# derive the value of JAVA_HOME.
# shellcheck disable=SC2120
get_java_home()
{
	# if it's already set, use the existing value.
	if [[ -n "$JAVA_HOME" ]]; then
		printf '%s\n' "$JAVA_HOME"
		return 0
	fi

	# derive JAVA_HOME from the java executable on PATH.
	# Optional Parameter to control the root dir of standard bin dirs
	local rootdir=$1
	local jexe
	local stdbindirs=${rootdir}/usr/java/latest/bin:${rootdir}/usr/lib/jvm/java/bin:${rootdir}/usr/lib/jvm/jre/bin
	jexe=$(PATH=$stdbindirs:$PATH which java)
	if [[ $? -ne 0 ]]; then
		errmsg "no java binary was found on PATH"
		return 1
	fi
	local abs_jexe=$jexe
	if [[ -h "$jexe" ]]; then
		# follow symlinks to find the real location.
		abs_jexe=$(readlink -f "$jexe")
		if [[ $? -ne 0 ]]; then
			errmsg "readlink failed on $jexe"
			return 1
		fi
	fi
	local jbin
	jbin=$(dirname "$abs_jexe")
	dirname "$jbin"
	return 0
}

#
# get the value of JAVA_HOME and save in apigee globals file.
# also prefix PATH with $JAVA_HOME/bin .
#
store_java_home()
{
	local file=$APIGEE_GLOBALS_FILE
	local jhome
	jhome=$(get_java_home)
	if [[ -z "$jhome" ]]; then
		errmsg "JAVA_HOME could not be determined"
		return 1
	fi
	Header "Storing JAVA_HOME=$jhome in $file"
	local pdir
	pdir=$(dirname "$file")
	mkdir -p -m 755 "$pdir" || return 1
	replace_var "$file" JAVA_HOME "$jhome"
        # ensure that JAVA_HOME is exported
        if ! grep -q '^export  *JAVA_HOME *$' "$file"; then
                echo "export JAVA_HOME" >> "$file"
        fi

	# the single-quoting is intentional.
	# shellcheck disable=SC2016
	replace_var "$file" PATH '$JAVA_HOME/bin:$PATH'

	# make it owned by the same user/group as APIGEE_ROOT.
	# shellcheck disable=SC2012,SC2155
	local id=$(ls -ld -- "$APIGEE_ROOT" | awk '{print $3 ":" $4}')
	notice "id=$id"
	chown "$id" "$pdir" "$file" || return 1
	return 0
}

# duplicated code from apigee-lib.sh .

#**
# *brief  in the given varfile, replace the assignment
#         to the given var, with the given value.
#
# *param file  name of the file to operate on.
# *param varname  name of the variable whose value is to be changed.
# *param value  text of new value to place in file.
# *return 0 on success, non-0 on failure.
#
# * edit the given FILE, looking for line(s) beginning with varname= ,
#   and replacing the rest of the line with value.
# * if it isn't there, add the assignment at the end.
# * FILE may be "-" to read from stdin.
# * this function should be idempotent.
#
# replace_var is arguably more reliable than using sed -e "s///",
# because sed has trouble if the VARIABLE name contains a dot,
# or if the VALUE string contains metachars or the sed delimiter char.
# perl substitutions neatly sidestep these issues.
# the perl version also creates if the assignment wasn't there already.
#
replace_var()
{
	if [ $# -ne 3 ]; then
		echo "Error: wrong number of arguments to replace_var"
		echo "usage: replace_var FILE VARNAME VALUE"
		return 1
	fi
	perl -i -e '
	use warnings FATAL => "all"; # force fail on i/o warnings
	$VALUE = pop @ARGV;
	$VARNAME = pop @ARGV;
	$seen = 0;
	$FILE = $ARGV[0];
	if ($FILE ne "-") {
		# make sure the target file exists, to avoid a warning message
		open(F, ">>", $FILE) or die("Error: $! --- cannot write to $FILE!\n");
		close(F);
	}
	else {
		# in this case <> will read STDIN
		shift @ARGV;
	}
	while (<>) {
		if (s/^\s*(\Q$VARNAME\E)=.*/$1=$VALUE/) {
			$seen = 1;
		}
		chomp;
		print $_, "\n";
	}
	if (!$seen) {
		# print STDERR "ADDING $VARNAME=$VALUE\n";
		if ($FILE eq "-") {
			print "$VARNAME=$VALUE\n";
		}
		else {
			#
			# we would like to just print here,
			# but perl has already closed the ARGV filehandle.
			# so we have to reopen it to append.
			#
			open(F, ">>", $FILE) or die("Error: $! --- cannot append to $FILE!\n");
			print F "$VARNAME=$VALUE\n";
			close(F) or die("Error: write failed on $FILE!\n");
		}
	}
	' "$@"
}

# check the installed version of java, return true if supported.
# the msg argument is optional, used for testing.
# shellcheck disable=SC2120
java_version()
{
	local msg
	msg=${1:-$(java -version 2>&1)}
	local xstat=$?
	if [[ $xstat -ne 0 ]]; then
		errmsg "java is not installed or not in PATH"
		return 1
	fi
	sed -n -e 's/.* vers.*"\(.*\)".*/\1/p' <<< "$msg"
}

#
# print the full java version, as a single line
# with space replaced by underscore, and newline replaced by /.
#
# the msg argument is optional, used for testing.
# shellcheck disable=SC2120
java_desc()
{
	local msg
	msg=${1:-$(java -version 2>&1)}
	tr 'A-Z \n' 'a-z_/' <<< "$msg"
}

# check that java is installed on PATH.
java_installed_check()
{
	Header "Checking that java is on PATH:"
	if hash java 2>&1; then
		DBG "OK - java is there"
	else
		errmsg "java not found"
	fi
}

#
# give user a choice of how to handle missing java.
# prompt for input from user, and print the corresponding choice.
#
sel_java_fix()
{
	local w
	set -- \
		"Install $DEFAULT_JAVA" \
		"Continue without java" \
		"Quit now"
	local eof=true
	select w; do
		if [[ -z "$w" ]]; then
			notice "Illegal input, try again"
		else
			DBG "w=$w REPLY=$REPLY"
			eof=false
			break
		fi
	done

	if $eof; then
		errmsg "EOF detected"
		return 1
	fi
	echo "${w:-Install}"
}

#
# check that a supported version of java is installed.
# if not, give user a choice of how to handle it.
# note that the java check has to be done separately from
# the other checks (which are done before configuring the
# package manager), since java may need to be installed
# which will need the package manager configuration to
# be done already.
#
java_check()
{
	if java_installed_check \
	 && java_brand_check \
	 && java_version_check; then
		DBG "OK - java is fine"
		return 0
	fi

	local w
	w=${JAVA_FIX:-$(sel_java_fix)}
	if [ $? -ne 0 ]; then
		return 1
	fi
	case "$w" in
	I*) gen_install "$DEFAULT_JAVA"; return $? ;;
	C*) notice "Continuing without java"; return 0 ;;
	Q*) notice "Quitting"; return 1 ;;
	esac
}

# check the installed java, return true if it is a supported version.
# the vers argument is optional, used for testing.
# shellcheck disable=SC2120
java_version_check()
{
	Header "Checking java version:"
	local vers
	vers=${1:-$(java_version)}
	if vcompare "$vers" "<" "$JAVA_MIN_VERSION" \
	 || vcompare "$vers" ">" "$JAVA_MAX_VERSION"; then
		errmsg "java_version=$vers is not supported -" \
		  "java must be between $JAVA_MIN_VERSION and $JAVA_MAX_VERSION"
		return 1
	fi
	DBG "OK - java_version=$vers is supported"
	return 0
}

# check the installed java, return true if it is a supported "brand".
# the desc argument is optional, used for testing.
# shellcheck disable=SC2120
java_brand_check()
{
	Header "Checking java brand:"
	local desc
	desc=${1:-$(java_desc)}
	DBG "java desc=$desc"
	local ok=false
	#
	# NOTE: the order of cases is important.
	# on some IBM java implementations,
	# the version string also contains the word "oracle".
	# so we check for ibm before checking for oracle.
	#
	case $desc in
	*ibm*) ok=false ;;
	*oracle*|*openjdk*) ok=true ;;
	*) ok=true ;;
	esac

	if $ok; then
		DBG "OK - java=$desc is supported"
	else
		errmsg "java=$desc is not supported"
	fi
}

#
# return true if the template uses the variable named by var,
# OR the var prefixed with "apigee".
#
# in order to be recognized,
# the reference must be of the form \{\{VAR\}\} with explicit
# curly braces, not just $var.
#
uses_var()
{
	local template=$1 var=$2

	# the literal {{}} references are intentional.
	# shellcheck disable=SC1083
	case $template in
	*{\{"$var"\}}*|*{\{apigee"$var"\}}*) return 0 ;;
	*) return 1 ;;
	esac
}

#
# expand all \{\{var\}\} references in the template (second arg).
# assign the result to the variable named by the first arg.
#
# this is a simplified variant of the script expand_template.sh .
#
eval_template()
{
	local _V=$1 _T=$2
	local _X
	# the single quoting is intentional.
	# shellcheck disable=SC2016
	_X=$(sed -e 's/{[{]\([^{} ][^{} ]*\)[}]}/\${\1}/g' <<< "$_T")
	# DBG "( _T=$_T )"
	# DBG "( _X=$_X )"
	eval "$_V=$_X"
}

#
# tell if credentials gathering should proceed,
# based on the value of global vars
# apigeeprotocol and apigeeuser.
#
creds_not_used()
{
	[[ "$apigeeprotocol" == "file://" ]] \
	|| [[ "$apigeeuser" == NONE ]]
}

#
# ensure that we have values for the global vars user and password
# OR that they are not needed.
#
# also sets the URL-encoded versions of the credentials,
# apigeeuser and apigeepassword.
#
obtain_creds()
{
	#
	# check apigeeuser/apigeepassword
	# just in case the user passed in those vars
	# by "mistake" instead of user/password.
	#
	: "${user:=$apigeeuser}"
	: "${password:=$apigeepassword}"

	creds_not_used && return

	Header "Obtaining creds for $apigeerepohost:"
	local var flags
	for var in user password; do
		if ! uses_var "$REPO_URL_TEMPLATE" "$var"; then
			continue
		fi
		flags=-rp
		[[ "$var" == "password" ]] && flags=-rsp
		while [[ -z "${!var}" ]]; do
			echo 1>&2 ""
			# the -r is in flags.
			# shellcheck disable=SC2162
			if ! IFS= read "$flags" \
			  "Please enter value for $var:" "$var"; then
				echo 1>&2 ""
				errmsg EOF detected
				return 1
			fi
		done
	done
	echo 1>&2 ""
	DBG "user=$user"
}

# cross-platform install of the given PACKAGES.
gen_install()
{
	local DISTRO
	DISTRO=${TEST_DISTRO:-$(_get_distro)}
	case $DISTRO in
	amazon_linux_ami*)
		_rh_install "$@" ;;
	rh*|redhat*|centos*|oracle_linux*)
		_rh_install "$@" ;;
	sles*)
		_sles_install "$@" ;;
	*)
		errmsg "sorry, distro=$DISTRO is not supported" ;;
	esac
}

# SUSE-specific install
_sles_install()
{
	"$MOCK_PREFIX" zypper install -y "$@"
}

# redhat-specific install
_rh_install()
{
	"$MOCK_PREFIX" yum install -y "$@"
}

# cross-platform configuration of package manager.
# the DISTRO argument is optional, used for testing.
# shellcheck disable=SC2120
gen_pm_config()
{
	local DISTRO
	DISTRO=${1:-${TEST_DISTRO:-$(_get_distro)}}
	Header "Configuring package manager:"

	apigeeuser=$(rawurlencode "$user")
	apigeepassword=$(rawurlencode "$password")
	export apigeecredentialswithat
	apigeecredentialswithat=$(mkcreds "$apigeeuser" "$apigeepassword")

	eval_template REPO_URL_BASE "$REPO_URL_TEMPLATE"
	# DBG "user=[$user] apigeeuser=[$apigeeuser]"
	# DBG "password=[$password] apigeepassword=[$apigeepassword]"
	DBG "REPO_URL_BASE = $REPO_URL_TEMPLATE => [$REPO_URL_BASE]"

	case $DISTRO in
	amazon_linux_ami*)
		_rh_pm_config ;;
	rh*|redhat*|centos*|oracle_linux*)
		_rh_pm_config ;;
	sles*)
		_sles_pm_config ;;
	*)
		errmsg "distro=$DISTRO is not supported" ;;
	esac
	if [[ $? -ne 0 ]]; then
		errmsg "Repo configuration failed"
		return 1
	fi
	return 0
}

# initialize vars used in the apigee.repo file.
# the dir argument is optional, for testing.
# shellcheck disable=SC2120
_set_yum_vars()
{
	local dir=${1:-$YUM_VARS_DIR}
	local vars=($(set -o posix; \
		set | sed -n -e 's/^\(apigee[^=]*\)=.*/\1/p'))
	local var val
	for var in "${vars[@]}"; do
		val=${!var}
		echo "$val" > "$dir/$var"
		notice "setting $var for yum"
		chmod 600 "$dir/$var"
	done
}

#
# print the basename of a package, removing the version number.
# if multiple arguments, treat each one as a package name.
#
_package_basename()
{
	local arg
	for arg in "$@"; do
	sed -e 's/-[0-9].*//' <<< "$arg"
	done
}

# remove any possible leftover version of the initial seed rpms
_remove_seed_rpms()
{
	local pkg
	# possible failure ignored on this command
	# the word-splitting is intentional.
	# shellcheck disable=SC2046,SC2086
	for pkg in $APIGEE_SEED_REPOS; do
		"$MOCK_PREFIX" \
		rpm -e $(_package_basename "$pkg") \
		|| ignore
	done
	return 0
}

# redhat-specific configuration of package manager.
_rh_pm_config()
{
	local ok=true

	# remove pre-existing apigee* vars to give clean slate
	/bin/rm -f "$YUM_VARS_DIR"/apigee*

	local already
	already=$($MOCK_PREFIX rpm -qa 'apigee*')
	if [[ -n "$already" ]]; then
		DBG "Pre-existing apigee packages:"
		DBG "$already"
		DBG ""
	fi

	_remove_seed_rpms

	"$MOCK_PREFIX" \
	yum install -y "$REPO_URL_BASE/$APIGEE_RH_REPO" \
	|| return 1

	"$MOCK_PREFIX" _set_yum_vars

	"$MOCK_PREFIX" \
	yum clean all
	return 0
}

# convert a redhat .repo file to a form usable by SUSE routines.
# the arguments are optional, for testing.
# shellcheck disable=SC2120
_convert_repo()
{
	#
	# zypper doesn't like doublequotes around the baseurl,
	# so we remove them.
	# zypper doesn't handle $variables, so we expand them here.
	#
	sed -e 's/^baseurl *= *"\(.*\)"/baseurl = \1/' "$@" \
	| perl -pe 's/\$(\w+)/$ENV{$1}/ge;'
	return 0
}

#
# select from the zypper listing, those entries whose name, alias, or URL
# contains the word "apigee".
# print the names (which may contain spaces), one per line.
# leading or trailing spaces are removed.
#
# the input argument is optional, for testing.
# shellcheck disable=SC2120
_sles_repo_filter()
{
	grep -w -i apigee "$@" \
	| cut -d\| -f3 \
	| sed -e 's/^  *//' -e 's/ *$//'
}

#
# compare 2 hierarchical version numbers.
# middle argument "op" is one of "<", "=", or ">".
# return true if A and B are in the relation specified by op.
#
vcompare()
{
	local IFS=" ._-"
	local A=($1) OP=$2 B=($3)
	local i ai bi maxi=${#B[*]}
	if ((maxi < ${#A[*]})); then
		maxi=${#A[*]}
	fi

	case $OP in
	"<"|"="|">") ;;
	*)
		echo 1>&2 "unknown operator \"$OP\" in vcompare"
		return 2
		;;
	esac

	for ((i = 0; i < maxi; i++)); do
		ai=10#${A[i]:-0} bi=10#${B[i]:-0}
		if (( ai < bi )); then
			[[ "$OP" == "<" ]]
			return
		elif (( ai > bi )); then
			[[ "$OP" == ">" ]]
			return
		fi
	done
	[[ "$OP" == "=" ]]
}

# print the names of any variables referenced in the repo file (stdin)
repo_vars()
{
	perl -ape \
	'if (m/\$/) { s/[^\$]*\$(\w*)[^\$]*/\1\n/g; } else { $_ = "" }' \
	| sort -u
}

# SUSE-specific configuration of package manager.
_sles_pm_config()
{
	local name
	local seed_rpm="$REPO_URL_BASE/$APIGEE_RH_REPO"

	# clean zypper cache
	"$MOCK_PREFIX" zypper clean -a

	# pre-remove all apigee repos
	"$MOCK_PREFIX" zypper lr -d \
	| _sles_repo_filter \
	| while IFS= read -r name; do
		"$MOCK_PREFIX" zypper removerepo "$name" \
		|| ignore
	done

	_remove_seed_rpms

	if [[ "$REPO_URL_BASE" == /* ]]; then
		"$MOCK_PREFIX" \
		rpm -ivh --nodeps "$REPO_URL_BASE/$APIGEE_RH_REPO" \
		|| return 1
	else
		#
		# can't use rpm directly since
		# it doesn't seem to like our https URL.
		#
		local tmpdir=/tmp/apigee-bootstrap-$$
		mkdir -p "$tmpdir"
		( cd "$tmpdir" \
		&& "$MOCK_PREFIX" wget --no-cache --no-cookies "$seed_rpm" \
		&& "$MOCK_PREFIX" rpm -ivh --nodeps "$(basename "$seed_rpm")" )
		local xstat=$?
		/bin/rm -rf "$tmpdir"
		if [[ $xstat -ne 0 ]]; then
			errmsg "_sles_pm_config failed!"
			return 1
		fi
	fi
	# configure to use the GPG key file contained in APIGEE_RH_REPO.
	"$MOCK_PREFIX" rpm --import "$APIGEE_GPG_KEY_FILE" \
	|| return 1

	if [[ -n "$ZYPPER_PASSWORD_BUG" ]]; then
		$TEST_DEBUG && [[ "$apigeepassword" != "$password" ]] \
		&& echo 1>&2 "(due to zypper bug, using apigeepassword=$password)"
		apigeepassword=$password
	fi

	vrun cp /dev/null "$APIGEE_SUSE_REPO_FILE" || return 1
	vrun chmod 600 "$APIGEE_SUSE_REPO_FILE" || return 1

	#
	# the lack of quoting is intentional.
	# all variables used in the .repo file will be exported
	# for use by _convert_repo.
	# shellcheck disable=SC2046,SC2086
	#
	export $(repo_vars < "$APIGEE_RH_REPO_FILE")
	local tmprepo="/tmp/bootstrap-suse-$$.repo"
	_convert_repo < "$APIGEE_RH_REPO_FILE" > "$tmprepo" \
	&& vrun zypper addrepo "$tmprepo"
	local ret=$?
	/bin/rm -f "$tmprepo"
	[[ "$ret" -eq 0 ]] || return 1

	"$MOCK_PREFIX" zypper lr -d | grep -w -i apigee
}

#
# check for presence of misc commands, return true if all present on PATH.
# each param is a command to check.
#
cmd_check()
{
	Header "Checking for presence of misc commands:"
	local ok=true
	local cmd
	for cmd in "$@"; do
		if ! hash "$cmd" 2>&1; then
			errmsg "$cmd not found"
			ok=false
		fi
	done
	if $ok; then
		DBG "OK - all commands found on PATH"
	else
		errmsg "one or more needed commands were not found on PATH"
	fi
}

# check that we're running as root
uid_check()
{
	local id
	id=${TEST_UID:-$(id -u)}
	if [[ "$id" -ne 0 ]]; then
		errmsg "this script must be run as root"
		return 1
	fi
	return 0
}

# slice out the USER:PASSWORD@ part of REPO_URL_TEMPLATE
remove_url_creds()
{
	local template=$1
	sed -e 's/{[{][^{}]*user[}]}:*{[{][^{}]*password[}]}@*//' <<< "$template"
}

# synthesize the value for "apigeecredentialswithat".
mkcreds()
{
	local user=$1 password=$2

	creds_not_used && return 0

	if ! uses_var "$REPO_URL_TEMPLATE" user; then
		return 0
	fi
	local ret="$1"
	if uses_var "$REPO_URL_TEMPLATE" password; then
		ret="${ret}:${password}"
	fi
	ret="${ret}@"

	printf "%s" "$ret"
}

# set production defaults for the required variables.
set_production_defaults()
{
	# ensure TEST_DEBUG is either true or false
	: "${TEST_DEBUG:=false}"
	[[ "$TEST_DEBUG" != true ]] && TEST_DEBUG=false

	# MOCK_PREFIX should be either vrun or nrun (for testing)
	: "${MOCK_PREFIX:=vrun}"
	: "${JAVA_FIX:=}"

	: "${apigeeprotocol:=https://}"
	export apigeeprotocol

	: "${DEFAULT_JAVA:=java-1.8.0-openjdk-devel}"
	: "${JAVA_MIN_VERSION:=1.8}"
	: "${JAVA_MAX_VERSION:=1.8.0.9999}"

	#
	# user and password are special variables.
	# they are the raw, user-visible credentials.
	# in contrast, apigeeuser and apigeepassword
	# are the URL-encoded credentials, used by yum
	# (via /etc/yum.repos.d/apigee.repo).
	# users "should not" need to be aware of
	# apigeeuser and apigeepassword.
	#
	: "${user:=}"
	: "${password:=}"
	export apigeeuser
	export apigeepassword

	# yum vars
	: "${apigeerepohost:=software.apigee.com}"
	: "${apigeereleasever:=4.18.05}"
	: "${apigeestage:=release}"
	: "${apigeepriostage:=release}"
	: "${apigeepriority:=5}"
	: "${apigeerepobasepath:=}"

	# TODO: this var is somewhat misleading, it's only for SUSE.
        local DISTRO=
        DISTRO=$(_get_distro | head -1)
        : "${releasever:=$DISTRO}"
	export releasever

	# APIGEE_RH_REPO - name of rpm for apigee-repo.
	: "${APIGEE_RH_REPO:=apigee-repo.rpm}"
	: "${APIGEE_RH_REPO_FILE:=/etc/yum.repos.d/apigee.repo}"

	# APIGEE_SEED_REPOS - repos to remove initially
	: "${APIGEE_SEED_REPOS:=apigee-repo apigeeprio-repo}"
	: "${APIGEE_SEED_REPOS:="apigee-repo apigeeprio-repo"}"

	: "${APIGEE_ROOT:=/opt/apigee}"

	: "${APIGEE_GLOBALS_FILE:=/opt/apigee/etc/defaults.sh}"

	REQUIRED_CMDS=(
	ls find awk grep egrep cat rm rmdir cp mv ln xargs
	)

	YUM_VARS_DIR=/etc/yum/vars
        APIGEE_GPG_KEY_FILE=/etc/pki/rpm-gpg/RPM-GPG-KEY-apigee

	: "${ZYPPER_PASSWORD_BUG:=true}"
	: "${SUSE_FORCE_UNSIGNED:=}"

	: "${REPO_URL_TEMPLATE:="{{apigeeprotocol}}{{apigeeuser}}:{{apigeepassword}}@{{apigeerepohost}}/{{apigeerepobasepath}}"}"
	: "${APIGEE_SUSE_REPO_FILE:=/etc/zypp/repos.d/apigee.repo}"
}

#
# ensure that perl is installed.
# since we use perl incidentally to help configure the repos,
# this check must be done before that.
#
perl_check()
{
	if ! hash perl 2>/dev/null; then
		gen_install perl
	fi
}

# get var settings from the command line.
set_overrides()
{
	PROGNAME=${0##*/}

	# take any command-line arguments as exports
	if [[ $# -gt 0 ]]; then
		# exporting this way is deliberate.
		# shellcheck disable=SC2163
		export "$@"
	fi

	#
	# HACK: adjust vars for compatibility with
	# older way of handling special cases.
	#
	if [[ "$apigeeprotocol" == "file://" ]]; then
		# the literal {} chars are intentional
		# shellcheck disable=SC1083
		REPO_URL_TEMPLATE={\{apigeerepobasepath\}}
		apigeerepohost=
		apigeeuser=NONE
		user=$apigeeuser
		password=
	fi
	if [[ "$apigeeuser" == NONE ]]; then
		REPO_URL_TEMPLATE="$(remove_url_creds "$REPO_URL_TEMPLATE")"
	fi
}

# run all the prerequisite checks, return true if all pass.
checks()
{
	cmd_check "${REQUIRED_CMDS[@]}" || return 1
	distro_check  || return 1
	arch_check    || return 1
	os_check      || return 1
	selinux_check || return 1
	uid_check     || return 1
	return 0
}

# do whatever downloads are needed, return true on success.
download()
{
	Header "Installing apigee-service:"
	gen_install apigee-service || return 1

	#
	# sometimes zypper fails with exit status 0.
	# so we have to check explicitly that the package is there.
	# this should probably be done in a more system-independent way.
	#
	"$MOCK_PREFIX" rpm -q apigee-service || return 1
}

# do the real work, return true on success.
work()
{
	Header "Begin work ..."
	checks         || return 1
	perl_check     || return 1
	gen_pm_config  || return 1
	java_check     || return 1
	download       || return 1
	store_java_home || return 1
	Header "End work - success!"
	return 0
}

#
# return true if the script is being run as opp to dotted in for testing.
# the first argument is the $0 from the mainline code.
#
running()
{
	[[ "${1##*/}" == "${BASH_SOURCE[0]##*/}" ]]
}

# dump variables that identify the version of bootstrap.
show_version()
{
	: "${BOOTSTRAP_VERSION:=Apigee bootstrap 1.0}"
	: "${BUILD_NUMBER:=379}"
	: "${BUILD_DATE:=2018.04.24,01:34}"
	: "${GIT_BRANCH:=origin/OPDK_1805}"
	echo 1>&2 "$BOOTSTRAP_VERSION-$BUILD_NUMBER ($GIT_BRANCH, $BUILD_DATE)"
}

# main contains all top-level bash code, return true on success.
main()
{
	show_version
	set_production_defaults
	set_overrides "$@" || return 1
	obtain_creds       || return 1

	# by default create files as readonly
	umask 022

	if [[ -n "$LOGFILE" ]]; then
		Header "Recording to $LOGFILE ..."
	else
		LOGFILE=/dev/null
	fi
	work 2>&1 | tee "$LOGFILE"

	return "${PIPESTATUS[0]}"
}

#
# rawurlencode function is copied from stackoverflow.
# http://stackoverflow.com/questions/296536/how-to-urlencode-data-for-curl-command
#
rawurlencode()
{
	printf '%s' "$*" \
	| perl -pe 's/([^\na-zA-Z0-9_.-])/sprintf("%%%02x", ord($1))/gse'
}

# ----- start of mainline code.  only the last line "runs"
if running "$0"; then main "$@"; fi
