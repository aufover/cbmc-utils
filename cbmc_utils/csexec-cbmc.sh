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
￼  echo "-l LOGDIR option is empty!"; exit 1
fi

# Build the arg string - prefix
# every cmd line argument with "--add-cmd-line-arg".
# ARGV[0] is path to the binary
GOTO_INSTRUMENT_ARGS=()
for arg in ${ARGV[*]:1}
do
        GOTO_INSTRUMENT_ARGS+=("--add-cmd-line-arg")
        GOTO_INSTRUMENT_ARGS+=("$arg")
done

# if no cmd line arguments, no reason for instrumentation
if [ ${#GOTO_INSTRUMENT_ARGS[@]} -eq 0 ]
then
        /usr/bin/env -i /usr/bin/bash -lc 'exec "$@"' cbmc \
            /usr/bin/timeout --signal=KILL $TIMEOUT \
            /usr/bin/cbmc --unwind 1 --verbosity 4 --json-ui \
            "${CBMC_ARGS[@]}"  "${ARGV[0]}" \
            2> "$LOGDIR/pid-$$.err" | /usr/bin/tee "$LOGDIR/pid-$$.out" | \
            cbmc-convert-output > "$LOGDIR/pid-$$.out.conv"
else
        /usr/bin/goto-instrument "${GOTO_INSTRUMENT_ARGS[@]}" \
        "${ARGV[0]}" "${ARGV[0]}.instrumented.$$" \
        2> $LOGDIR/gi-$$.err > "$LOGDIR/gi-$$.log"

        /usr/bin/env -i /usr/bin/bash -lc 'exec "$@"' cbmc \
            /usr/bin/timeout --signal=KILL $TIMEOUT \
            /usr/bin/cbmc --unwind 1 --verbosity 4 --json-ui \
            "${CBMC_ARGS[@]}"  "${ARGV[0]}.instrumented.$$" \
            2> "$LOGDIR/pid-$$.err" | /usr/bin/tee "$LOGDIR/pid-$$.out" | \
            cbmc-convert-output > "$LOGDIR/pid-$$.out.conv"
fi

exec $(/usr/bin/csexec --print-ld-exec-cmd ${CSEXEC_ARGV0}) "${ARGV[@]}"
