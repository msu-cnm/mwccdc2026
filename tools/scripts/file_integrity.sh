#!/usr/bin/env bash 

watchlist="$1"

if [[ -z "$watchlist" ]]; then
  echo "Usage: $0 <watchlist.txt>"
  exit 1
fi

if [[ ! -f "$watchlist" ]]; then
  echo "Watchlist not found: $watchlist"
  exit 1
fi

echo "Initializing hashes..."

declare -A hashes

while IFS= read -r file; do
  [[ -f "$file" ]] || continue
  hash=$(sha256sum "$file" | awk '{print $1}')
  hashes["$file"]="$hash"
  echo "$(date +"%Y-%m-%d %H:%M:%S") $file | $hash"
done < "$watchlist"

echo "Monitoring..."

while true; do
  while IFS= read -r file; do
    if [[ -f "$file" ]]; then
      new_hash=$(sha256sum "$file" | awk '{print $1}')
      old_hash=${hashes["$file"]}

      if [[ "$new_hash" != "$old_hash" ]]; then
        echo "$(date +"%Y-%m-%d %H:%M:%S") File changed: $file"
        hashes["$file"]="$new_hash"
      fi
    
    else
      echo "$(date +"%Y-%m-%d %H:%M:%S") File missing: $file"
    fi
  done < "$watchlist"

  sleep 60
done
