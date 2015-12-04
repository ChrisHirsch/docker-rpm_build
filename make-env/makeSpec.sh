#!/bin/bash
#
# Builds an rpm spec file
#
# Called from make.rules (target "pkg"), and assumes several environment vars
# are defined:  VERSION, BUILD_NUMBER, etc.
# (as well as a bunch of spec vars set in spec.defs file)
#

USAGE="Usage: ${0##*/} [-v] [-x <ReleaseExtraTag>] [-s <SpecfileInputDir> [-o <OutputDir>]] <Project> <BuildRoot>"

RELEASE_EXTRA_TAG=
OUTPUT_DIR=.
SPEC_INPUT=
VERBOSE=

OPTIND=1
while getopts "o:s:vx:" opt; do
	case "$opt" in
	o)
		OUTPUT_DIR=${OPTARG}
		;;
	s)
		SPEC_INPUT=${OPTARG}
		;;
	v)
		VERBOSE=1
		;;
	x)
		RELEASE_EXTRA_TAG=.${OPTARG}
		;;
	\?)
		echo "Invalid option: -$OPTARG" >&2
		echo $USAGE >&2
		exit 1
		;;
	:)
		echo "Option -$OPTARG requires an argument." >&2
		echo $USAGE >&2
		exit 1
		;;
	esac
done
shift $((OPTIND-1))

PROJECT=$1
INSTALL_ROOT=$2
if [ -z "${PROJECT}" ] || [ -z "${INSTALL_ROOT}" ]; then
	echo "PROJECT and INSTALL_ROOT arguments required." >&2
	echo ${USAGE} >&2
	exit 1
fi

SPEC_INPUT=${SPEC_INPUT:-${INSTALL_ROOT}/../../env}

if [ -n "${VERBOSE}" ]; then
	echo PROJECT=${PROJECT}
	echo INSTALL_ROOT=${INSTALL_ROOT}
	echo OUTPUT_DIR=${OUTPUT_DIR}
	echo SPEC_INPUT=${SPEC_INPUT}
	echo RELEASE_EXTRA_TAG=${RELEASE_EXTRA_TAG}
fi

DIRS_FILE=$SPEC_INPUT/spec.dirs
[ -f $DIRS_FILE ] || DIRS_FILE=/dev/null
DIR_EXCLUDES_GLOBAL=${0%/*}/spec.excludeDirs
[ -f $DIR_EXCLUDES_GLOBAL ] || DIR_EXCLUDES_GLOBAL=/dev/null

if [ ! -f $SPEC_INPUT/spec.defs ]; then
    echo "Couldn't find build env dir" >&2
    echo ${USAGE} >&2
    exit 1
fi

source  $SPEC_INPUT/spec.defs || exit 1	# Load rpm spec definitions

exec > $OUTPUT_DIR/$PROJECT.spec		# Redirect stdout to create spec file


# Build the header
echo "# This spec file is generated; so editing it may not be what you want."

cat $SPEC_INPUT/spec.defines 2> /dev/null

echo "Name: $PROJECT"
echo "Summary: $SUMMARY"
echo "Version: $VERSION"
# Conditionally append OS Vendor to Release (for all but noarch builds)
if [ -z "$OS_VENDOR" ]; then
   echo "Release: ${BUILD_NUMBER}"
else
   echo "Release: $BUILD_NUMBER.${OS_VENDOR}${RELEASE_EXTRA_TAG}"
fi
echo "Group: $GROUP"
echo "BuildRoot: ${BUILDROOT:-$INSTALL_ROOT}"
echo "Prefix: $PREFIX"

[ -n "$OBSOLETES" ] && echo "Obsoletes: $OBSOLETES"
[ -n "$CONFLICTS" ] && echo "Conflicts: $CONFLICTS"
[ -n "$PREREQ" ] && echo "Prereq: $PREREQ"
[ -n "$REQUIRES" ] && echo "Requires: $REQUIRES"
[ -n "$BUILDARCH" ] && echo "BuildArch: $BUILDARCH"
[ -n "$PROVIDES" ] && echo "Provides: $PROVIDES"

echo "Vendor: $VENDOR"
echo "Packager: $PACKAGER"
echo "License: $LICENSE"

# Build the description
echo ""
echo "%description"
cat $SPEC_INPUT/spec.description 2> /dev/null

# If we are picking up silly dependencies or provides you can filter
# these like FILTER_PROVIDES = badlib.so
[ -n "$FILTER_PROVIDES" ] && echo "%filter_provides_in $FILTER_PROVIDES"
[ -n "$FILTER_REQUIRES" ] && echo "%filter_requires_in $FILTER_REQUIRES"
[ -n "$FILTER_PROVIDES" -o -n "$FILTER_REQUIRES" ] && echo "%filter_setup"

# Build the file list
echo ""
echo "%files"
DEFAULT_OWNER=`awk '$2 == "default" {print $1}' $SPEC_INPUT/spec.ownership 2>/dev/null`
[ -n "$DEFAULT_OWNER" ] || DEFAULT_OWNER=-,-
oIFS="$IFS" IFS=$'\n'  # Handle spaces in filenames

for file in `find $INSTALL_ROOT -type f -o -type l | grep -v RPMS | sed "s%$INSTALL_ROOT%%"` 
do

   OCTAL=`stat -c %a $INSTALL_ROOT/$file`
   FILE_OWNER=`awk -v file=$file '$2 == file {print $1}' $SPEC_INPUT/spec.ownership 2>/dev/null`
   DIRECTIVE=`awk -v file=$file '$2 == file {print " ", $1}' $SPEC_INPUT/spec.directives 2>/dev/null`
   [ "${file/ /}" != "$file" ] && file="\"$file\""    # Quote if contains space
   echo "%attr(0$OCTAL,${FILE_OWNER:-$DEFAULT_OWNER})${DIRECTIVE} $file"

done

# Build the dir list
echo ""
DIR_START_LIST=`awk '$1 == "+" { print "./" $2 }' $DIRS_FILE`
for dir in `cd $INSTALL_ROOT && find ${DIR_START_LIST:-"./$PREFIX"} -type d |
   sed "s%^\./%%" | grep -v RPMS` 
do

   # Skip/exclude any directory found in the $DIR_EXCLUDES_GLOBAL file list
   # (unless the owning project matches)
   awk -v dir=$dir -v project=$PROJECT '
      $1 !~ /^[#+]/  &&  $1 != project  &&  $2 == dir  {
	  if (index($1, "|" project "|") == 0) exit 1
      }' $DIRS_FILE $DIR_EXCLUDES_GLOBAL ||
         continue
   OCTAL=`stat -c %a $INSTALL_ROOT/$dir`
   FILE_OWNER=`awk -v dir=$dir '$2 == dir {print $1}' $SPEC_INPUT/spec.ownership 2>/dev/null`
   DIRECTIVE=`awk -v dir=$dir '$2 == dir {print " ", $1}' $SPEC_INPUT/spec.directives 2>/dev/null`
   [ "${dir/ /}" != "$dir" ] && dir="\"$dir\""    # Quote if contains space
   echo "%dir %attr(0$OCTAL,${FILE_OWNER:-$DEFAULT_OWNER})${DIRECTIVE} $dir"

done
IFS="$oIFS"

# Add in any config directives
# Using config(noreplace) because that's probably what everybody wants
# http://www-uxsup.csx.cam.ac.uk/~jw35/docs/rpm_config.html for details
if [ -e $SPEC_INPUT/spec.config ]; then
   echo ""
   for config in `cat $SPEC_INPUT/spec.config`
   do
      echo "%config(noreplace) $config"
   done
fi

# Add in any scriptlets
for tag in pre post preun postun posttrans; do
   scriptlet=$SPEC_INPUT/spec.$tag
   if [ -f $scriptlet ]; then
       echo ""
       echo %$tag
       cat $scriptlet
   fi
done

# TODO: Add in changelog if configured
if [ -f $SPEC_INPUT/changelog ]; then
   # Consider doing something like:
   #    hg log --template '* {date|shortdate} <{author|email}>\n- {desc}'
   :
fi
