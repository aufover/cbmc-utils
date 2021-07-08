#!/usr/bin/bash

#set -x

usage() {
  cat << EOF
USAGE:
1) $ export PATH='\$(cswrap --print-path-to-wrap):\$PATH'
2) $ export CSWRAP_ADD_CFLAGS='-Wl,--dynamic-linker,/usr/bin/csexec-loader'
3) Build the source with 'goto-gcc'
4) $ CSEXEC_WRAP_CMD=$'--skip-ld-linux\acsexec-cbmc\a-l\aLOGSDIR\a-c\a--unwind 1 ...' make check
EOF
}

[[ $# -eq 0 ]] && usage && exit 1

# TODO
# add time-out option, something like "/usr/bin/timeout --signal=KILL <number>"
# xhwxk that number is number

while getopts "l:c:t:h" opt; do
  case "$opt" in
    c)
      CBMC_ARGS=($OPTARG)
      ;;
    h)
      usage && exit 0
      ;;
    l)
      LOGDIR="$OPTARG"
      ;;
    t)
      TIMEOUT="$OPTARG"
      ;;
    *)
      usage && exit 1
      ;;
  esac
done

shift $((OPTIND - 1))
ARGV=("$@")

if [ -z "$LOGDIR" ]; then
   name=`$(pwd)/LOGSDIR`
   mkdir $name
￼  echo "$name created!"
   LOGDIR=$name
fi

# Verify
echo "Executing cbmc ${CBMC_ARGS[*]} ${ARGV[0]}" 1> /dev/tty 2>&1
timeout --signal=KILL $TIMEOUT cbmc "${CBMC_ARGS[@]}"  "${ARGV[0]}" 2> "$LOGDIR/pid-$$.err" > "$LOGDIR/pid-$$.out"
1> /dev/tty 2>&1

exec $(csexec --print-ld-exec-cmd) "${ARGV[@]}"
