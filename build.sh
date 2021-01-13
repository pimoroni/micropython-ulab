#!/bin/sh
# POSIX compliant version
readlinkf_posix() {
  [ "${1:-}" ] || return 1
  max_symlinks=40
  CDPATH='' # to avoid changing to an unexpected directory

  target=$1
  [ -e "${target%/}" ] || target=${1%"${1##*[!/]}"} # trim trailing slashes
  [ -d "${target:-/}" ] && target="$target/"

  cd -P . 2>/dev/null || return 1
  while [ "$max_symlinks" -ge 0 ] && max_symlinks=$((max_symlinks - 1)); do
    if [ ! "$target" = "${target%/*}" ]; then
      case $target in
        /*) cd -P "${target%/*}/" 2>/dev/null || break ;;
        *) cd -P "./${target%/*}" 2>/dev/null || break ;;
      esac
      target=${target##*/}
    fi

    if [ ! -L "$target" ]; then
      target="${PWD%/}${target:+/}${target}"
      printf '%s\n' "${target:-/}"
      return 0
    fi

    # `ls -dl` format: "%s %u %s %s %u %s %s -> %s\n",
    #   <file mode>, <number of links>, <owner name>, <group name>,
    #   <size>, <date and time>, <pathname of link>, <contents of link>
    # https://pubs.opengroup.org/onlinepubs/9699919799/utilities/ls.html
    link=$(ls -dl -- "$target" 2>/dev/null) || break
    target=${link#*" $target -> "}
  done
  return 1
}
set -e
HERE="$(dirname -- "$(readlinkf_posix -- "${0}")" )"
[ -e micropython/py/py.mk ] || git clone https://github.com/micropython/micropython
[ -e micropython/lib/libffi/autogen.sh ] || (cd micropython && git submodule update --init lib/libffi )
#git clone https://github.com/micropython/micropython
make -C micropython/mpy-cross -j$(nproc)
make -C micropython/ports/unix -j$(nproc) deplibs
make -C micropython/ports/unix -j$(nproc) USER_C_MODULES="${HERE}" DEBUG=1 STRIP=:


for dir in "numpy" "common"
do
	if ! env MICROPY_MICROPYTHON=micropython/ports/unix/micropython ./run-tests -d tests/"$dir"; then
		for exp in *.exp; do
			testbase=$(basename $exp .exp);
			echo -e "\nFAILURE $testbase";
			diff -u $testbase.exp $testbase.out;
		done
	fi
done
