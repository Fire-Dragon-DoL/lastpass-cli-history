#!/usr/bin/env bash
##
## Usage: lpass-history-extract.sh
##
##

# TODO:
# - the -l option is **required**
# - lot of "login spam" to reduce skipped items
# - configurable paths for failed and skipped ids

# How to use:
# Copy your lastpass password to the clipboard, since you will need to type
# it many, many times. Then execute the following command:
#
# DEBUG=on ./lpass-history-extract.sh -l 'YOURUSERNAME' | tee password-history.csv

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

if ! lpass status 1>&2; then
  if [ -z ${email} ]; then
    echo "No login data found, Please login with -l or use lpass login before."
    exit 1;
  fi
  lpass login "$email" 1>&2
fi

if [ -z ${id} ]; then
  ids=$(lpass ls | sed -n "s/^.*id:\s*\([0-9]*\).*$/\1/p")
else
  ids=${id}
fi

do_login() {
  local login_result
  >&2 echo
  lpass login "$email" 1>&2
  login_result=$?
  >&2 echo
  return $login_result
}

echo '"Path","ID","Modified Date","Password"'
total_entries=$(echo "$ids" | wc -l)
entries_done=0
failed_ids=""
skipped_ids=""

for id in ${ids}; do
  (( entries_done+=1 ))
  if [[ "$DEBUG" = "on" ]]; then
    >&2 printf "%d/%d\n" "${entries_done}" "${total_entries}"
  fi

  # --format="%/as%/ag%an,%ai,%fn,\"%fv\""
  # %/as%/ag%an = similar to a "full path including entry name"
  #   %as = account share name
  #   %ag = account group (?)
  #   %an = account name (?)
  # %ai = ID
  # %fn = field name (date)
  # %fv = field value (password decrypted)
  raw_history=$(lpass history --color=never --format="\"%ai\",\"%fn\",\"%fv\"" "${id}")
  history_result=$?
  if [[ ! $history_result -eq 0 ]]; then
    do_login
    raw_history=$(lpass history --color=never --format="\"%ai\",\"%fn\",\"%fv\"" "${id}")
    if [[ ! $? -eq 0 ]]; then
      >&2 echo "Failed ${id}"
      printf -v failed_ids "%s\n%s" "$failed_ids" "$id"
      continue
    fi
  fi
  text_history=$(echo "$raw_history" | tail -n '+2')

  # NO history, ignore record
  if [[ "$text_history" = "" ]]; then
    continue
  fi

  itemname=$(lpass show --name ${id})
  itemname_result=$?
  if [[ ! $itemname_result -eq 0 ]]; then
    do_login
    itemname=$(lpass show --name ${id})
    if [[ ! $? -eq 0 ]]; then
      >&2 echo "Failed ${id}"
      printf -v failed_ids "%s\n%s" "$failed_ids" "$id"
      continue
    fi
  fi

  path=$(lpass show --format="%/as%/ag%an" ${id} | uniq | tail -1)
  path=${path//\\//}
  full_path="${path}/${itemname}"

  # If password history has 1 entry and equals current value, SKIP
  history_count=$(echo "$text_history" | wc -l)
  if [[ $history_count -eq 1 ]]; then
    current_password=$(lpass show --password "${id}")
    previous_password=$(lpass history --color=never --format="%fv" "${id}")
    if [[ "$current_password" = "$previous_password" ]]; then
      >&2 echo "Skipping Identical ${id}"
      printf -v skipped_ids "%s\n%s" "$skipped_ids" "$id"
      continue
    fi
  fi

  # Ensure lines are split over newlines, not any whitespace
  IFS=$'\n'
  for history_line in ${text_history}; do
    printf '"%s",%s\n' "$full_path" "$history_line"
  done
  # Must be reset afterward
  unset IFS
done

if [[ ! "$failed_ids" = "" ]]; then
  printf "ID%s" "$failed_ids" > "$PWD/failed_history_ids.csv"
  >&2 echo "Failed IDs written"
fi

if [[ ! "$skipped_ids" = "" ]]; then
  printf "ID%s" "$skipped_ids" > "$PWD/skipped_history_ids.csv"
  >&2 echo "Skipped IDs written"
fi

>&2 echo "Done"
