#!/usr/bin/env bash
##
## Usage: lpass-att-list.sh
##
##

usage() { echo "Usage: $0 [-l <email>] [-i <id>]" 1>&2; exit 1; }

while getopts ":i:o:hl:" o; do
    case "${o}" in
        i)
            id=${OPTARG}
            ;;
        l)
            email=${OPTARG}
            ;;
        h)
            usage
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

command -v lpass >/dev/null 2>&1 || { echo >&2 "I require lpass but it's not installed.  Aborting."; exit 1; }

if ! lpass status; then
  if [ -z ${email} ]; then
    echo "No login data found, Please login with -l or use lpass login before."
    exit 1;
  fi
  lpass login ${email}
fi

if [ -z ${id} ]; then
  ids=$(lpass ls | sed -n "s/^.*id:\s*\([0-9]*\).*$/\1/p")
else
  ids=${id}
fi

for id in ${ids}; do
  json_history_array=$(lpass history --json "${id}" | jq .history)

  # NO history, ignore record
  if [[ "$json_history_array" = "[]" ]]; then
    continue
  fi

  itemname=$(lpass show --name ${id})
  # path=$(lpass show --format="%/as%/ag%an" ${id} | uniq | tail -1)
  # path=${path//\\//}

  echo "$itemname"
  echo "$json_history_array"
done
