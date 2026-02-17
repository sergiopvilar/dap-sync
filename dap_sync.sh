#!/usr/bin/env bash
set -euo pipefail

SYNC_SELECTION_FILE="./sync_selection.txt"
DST="{{MUSIC_DESTINATION}}"
AUDIOBOOKS_DST="{{AUDIOBOOKS_DESTINATION}}"
MUSIC_DIRECTORY="{{MUSIC_DIRECTORY}}"
AUDIOBOOKS_DIRECTORY="{{AUDIOBOOKS_DIRECTORY}}"

echo "========== SYNC MUSIC & AUDIOBOOKS =========="
echo "Music Source      : $MUSIC_DIRECTORY"
echo "Music Destination : $DST"
echo "Audiobooks Source : $AUDIOBOOKS_DIRECTORY"
echo "Audiobooks Dest   : $AUDIOBOOKS_DST"
echo

# Safety checks
[[ -d "$MUSIC_DIRECTORY" ]] || { echo "ERROR: Music source not found."; exit 1; }
[[ -d "$DST" ]] || { echo "ERROR: Music destination not mounted."; exit 1; }
[[ -d "$AUDIOBOOKS_DIRECTORY" ]] || { echo "WARNING: Audiobooks source not found, skipping audiobooks sync."; }

# FAT32-safe rsync options
RSYNC_OPTS=(
  -rltv
  --progress
  --delete
  --inplace
  --no-owner
  --no-group
  --no-perms
  --chmod=ugo=rwX
  --modify-window=1
)

echo "Starting rsync..."
echo

# Read sync selection file
MUSIC_SYNC_ALL=true
SELECTED_MUSIC_ALBUMS=()
AUDIOBOOKS_SYNC_ALL=true
SELECTED_AUDIOBOOKS=()

if [ -f "$SYNC_SELECTION_FILE" ]; then
  
  while IFS= read -r line || [ -n "$line" ]; do
    line=$(echo "$line" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    # Skip empty lines and comments
    [ -z "$line" ] && continue
    [ "${line#\#}" != "$line" ] && continue
    
    if [[ "$line" == MUSIC_ALBUM=* ]]; then
      album_path="${line#MUSIC_ALBUM=}"
      album_path="${album_path#"${album_path%%[![:space:]]*}"}"  # trim leading whitespace
      album_path="${album_path%"${album_path##*[![:space:]]}"}"  # trim trailing whitespace
      if [ -n "$album_path" ]; then
        SELECTED_MUSIC_ALBUMS+=("$album_path")
      fi
    elif [[ "$line" == AUDIOBOOKS=* ]]; then
      audiobook_path="${line#AUDIOBOOKS=}"
      audiobook_path="${audiobook_path#"${audiobook_path%%[![:space:]]*}"}"  # trim leading whitespace
      audiobook_path="${audiobook_path%"${audiobook_path##*[![:space:]]}"}"  # trim trailing whitespace
      if [ -n "$audiobook_path" ]; then
        SELECTED_AUDIOBOOKS+=("$audiobook_path")
      fi
    fi
  done < "$SYNC_SELECTION_FILE"
  
  # Set sync flags: if arrays are empty, sync all; otherwise sync only selected
  if [ ${#SELECTED_MUSIC_ALBUMS[@]} -eq 0 ]; then
    MUSIC_SYNC_ALL=true
  else
    MUSIC_SYNC_ALL=false
  fi
  
  if [ ${#SELECTED_AUDIOBOOKS[@]} -eq 0 ]; then
    AUDIOBOOKS_SYNC_ALL=true
  else
    AUDIOBOOKS_SYNC_ALL=false
  fi
else
  echo "No selection file found at $SYNC_SELECTION_FILE, syncing ALL"
fi

# Sync Music
echo "========== SYNCING MUSIC =========="
if [ "$MUSIC_SYNC_ALL" = true ]; then
  echo "Music sync mode: ALL albums"
  rsync "${RSYNC_OPTS[@]}" "$MUSIC_DIRECTORY" "$DST/"
else
  echo "Music sync mode: SELECTED albums (${#SELECTED_MUSIC_ALBUMS[@]} album(s))"
  if [ ${#SELECTED_MUSIC_ALBUMS[@]} -eq 0 ]; then
    echo "WARNING: No music albums selected, removing all albums from destination"
    # Remove all albums from destination when none are selected
    rm -rf "$DST"/*
  else
    # First, sync all selected albums
    for album_path in "${SELECTED_MUSIC_ALBUMS[@]}"; do
      # album_path should be a full host path from sync_selection.txt (e.g., /Users/sergio/Music/...)
      if [ -d "$album_path" ]; then
        echo "Syncing music: $album_path"
        # Extract relative path for destination structure
        if [[ "$album_path" == "$MUSIC_DIRECTORY"* ]]; then
          relative_path="${album_path#$MUSIC_DIRECTORY}"
          # Remove leading slash if present
          relative_path="${relative_path#/}"
          # Build destination path and ensure parent directory exists
          dest_path="$DST/$relative_path"
          mkdir -p "$dest_path"
          # Use rsync to copy the album directory contents to the destination
          # Note: rsync source/ dest/ copies contents of source into dest
          rsync "${RSYNC_OPTS[@]}" "$album_path/" "$dest_path/"
        else
          echo "WARNING: Album path doesn't match MUSIC_DIRECTORY: $album_path"
          # Use album name as destination fallback
          album_name=$(basename "$album_path")
          mkdir -p "$DST"
          rsync "${RSYNC_OPTS[@]}" "$album_path/" "$DST/$album_name/"
        fi
      else
        echo "WARNING: Album not found: $album_path"
      fi
    done
    
    # Now remove albums from destination that are not in the selection
    echo "Removing albums not in selection..."
    # Build list of expected paths (relative to DST) - only exact album paths
    temp_expected_list=$(mktemp)
    for album_path in "${SELECTED_MUSIC_ALBUMS[@]}"; do
      if [[ "$album_path" == "$MUSIC_DIRECTORY"* ]]; then
        relative_path="${album_path#$MUSIC_DIRECTORY}"
        relative_path="${relative_path#/}"
        echo "$relative_path" >> "$temp_expected_list"
      fi
    done
    
    # Debug: show expected paths
    if [ -s "$temp_expected_list" ]; then
      echo "  Expected paths:"
      while IFS= read -r ep; do
        echo "    - '$ep'"
      done < "$temp_expected_list"
    else
      echo "  WARNING: Expected list is empty!"
    fi
    
    # Find and remove directories/files in destination that are not in expected paths
    if [ -d "$DST" ]; then
      echo "  Scanning destination directory..."
      temp_remove_list=$(mktemp)
      temp_all_items=$(mktemp)
      
      # First, collect all items
      find "$DST" \( -type d -o -type f \) > "$temp_all_items"
      total_items=$(wc -l < "$temp_all_items" | tr -d ' ')
      echo "  Found $total_items items to check"
      
      item_num=0
      while IFS= read -r dest_item; do
        [ "$dest_item" = "$DST" ] && continue
        
        item_num=$((item_num + 1))
        if [ $((item_num % 50)) -eq 0 ]; then
          echo "  Processed $item_num/$total_items items..."
        fi
        
        # Remove DST prefix to get relative path (handle DST with or without trailing slash)
        dst_normalized="${DST%/}"
        relative_item="${dest_item#$dst_normalized/}"
        # If removal didn't work, try with trailing slash
        if [ "$relative_item" = "$dest_item" ]; then
          relative_item="${dest_item#$DST}"
          relative_item="${relative_item#/}"
        fi
        
        found=false
        
        # Debug: show first few items being checked
        if [ $item_num -le 5 ]; then
          echo "  DEBUG: Checking item $item_num: dest='$dest_item', DST='$DST', relative='$relative_item'"
        fi
        
        # Check if this item is inside any expected path (item is a descendant of expected)
        # OR if this item is an ancestor of any expected path (needed for parent directories)
        if [ -s "$temp_expected_list" ]; then
          while IFS= read -r expected_path; do
            # Check if relative_item equals expected_path exactly
            if [ "$relative_item" = "$expected_path" ]; then
              if [ $item_num -le 5 ]; then
                echo "    DEBUG: Found exact match with '$expected_path'"
              fi
              found=true
              break
            fi
            # Check if relative_item starts with expected_path/ (item is descendant of expected)
            expected_prefix="${expected_path}/"
            stripped="${relative_item#$expected_prefix}"
            if [ "$stripped" != "$relative_item" ]; then
              if [ $item_num -le 5 ]; then
                echo "    DEBUG: Found prefix match - '$relative_item' starts with '$expected_prefix'"
              fi
              found=true
              break
            fi
            # Check if expected_path starts with relative_item/ (item is ancestor of expected)
            relative_prefix="${relative_item}/"
            expected_stripped="${expected_path#$relative_prefix}"
            if [ "$expected_stripped" != "$expected_path" ]; then
              if [ $item_num -le 5 ]; then
                echo "    DEBUG: Found ancestor match - '$expected_path' starts with '$relative_prefix'"
              fi
              found=true
              break
            fi
            if [ $item_num -le 5 ]; then
              echo "    DEBUG: No match - '$relative_item' vs '$expected_path'"
            fi
          done < "$temp_expected_list"
        fi
        
        # Also check if any parent of this item is exactly in expected list
        if [ "$found" = false ]; then
          current_relative="$relative_item"
          depth=0
          while [ -n "$current_relative" ] && [ "$current_relative" != "." ] && [ $depth -lt 10 ]; do
            if grep -Fxq "$current_relative" "$temp_expected_list" 2>/dev/null; then
              if [ $item_num -le 5 ]; then
                echo "    DEBUG: Found parent match - parent '$current_relative' is in expected list"
              fi
              found=true
              break
            fi
            parent_relative="$(dirname "$current_relative")"
            if [ "$parent_relative" = "$current_relative" ] || [ "$parent_relative" = "." ]; then
              break
            fi
            current_relative="$parent_relative"
            depth=$((depth + 1))
          done
        fi
        
        if [ "$found" = false ]; then
          if [ $item_num -le 5 ]; then
            echo "    DEBUG: Item '$relative_item' NOT FOUND - will be removed"
          fi
          echo "$dest_item" >> "$temp_remove_list"
        else
          if [ $item_num -le 5 ]; then
            echo "    DEBUG: Item '$relative_item' FOUND - will be kept"
          fi
        fi
      done < "$temp_all_items"
      
      rm -f "$temp_all_items"
      
      # Remove items not in selection (process in reverse order to remove children before parents)
      if [ -s "$temp_remove_list" ]; then
        sort -r "$temp_remove_list" | while read -r item_to_remove; do
          if [ -e "$item_to_remove" ]; then
            echo "Removing item not in selection: $item_to_remove"
            rm -rf "$item_to_remove"
          fi
        done
      fi
      
      rm -f "$temp_remove_list"
    fi
    
    rm -f "$temp_expected_list"
  fi
fi

# Sync Audiobooks
if [ -d "$AUDIOBOOKS_DIRECTORY" ]; then
  echo
  echo "========== SYNCING AUDIOBOOKS =========="
  if [ "$AUDIOBOOKS_SYNC_ALL" = true ]; then
    echo "Audiobooks sync mode: ALL"
    # Sync all files and directories from audiobooks source
    rsync "${RSYNC_OPTS[@]}" "$AUDIOBOOKS_DIRECTORY" "$AUDIOBOOKS_DST/"
  else
    echo "Audiobooks sync mode: SELECTED (${#SELECTED_AUDIOBOOKS[@]} audiobook(s))"
    if [ ${#SELECTED_AUDIOBOOKS[@]} -eq 0 ]; then
      echo "WARNING: No audiobooks selected, removing all audiobooks from destination"
      # Remove all audiobooks from destination when none are selected
      rm -rf "$AUDIOBOOKS_DST"/*
    else
      # First, sync all selected audiobooks
      for audiobook_path in "${SELECTED_AUDIOBOOKS[@]}"; do
        # audiobook_path should be a full host path from sync_selection.txt (e.g., /Users/sergio/Library/...)
        if [ -d "$audiobook_path" ] || [ -f "$audiobook_path" ]; then
          echo "Syncing audiobook: $audiobook_path"
          # Extract relative path for destination structure
          if [[ "$audiobook_path" == "$AUDIOBOOKS_DIRECTORY"* ]]; then
            relative_path="${audiobook_path#$AUDIOBOOKS_DIRECTORY}"
            relative_path="${relative_path#/}"
            dest_path="$AUDIOBOOKS_DST/$relative_path"
            # Ensure destination directory exists
            if [ -d "$audiobook_path" ]; then
              mkdir -p "$dest_path"
              rsync "${RSYNC_OPTS[@]}" "$audiobook_path/" "$dest_path/"
            else
              mkdir -p "$(dirname "$dest_path")"
              rsync "${RSYNC_OPTS[@]}" "$audiobook_path" "$dest_path"
            fi
          else
            echo "WARNING: Audiobook path doesn't match AUDIOBOOKS_DIRECTORY: $audiobook_path"
            # Use basename as destination fallback
            audiobook_name=$(basename "$audiobook_path")
            if [ -d "$audiobook_path" ]; then
              mkdir -p "$AUDIOBOOKS_DST"
              rsync "${RSYNC_OPTS[@]}" "$audiobook_path/" "$AUDIOBOOKS_DST/$audiobook_name/"
            else
              mkdir -p "$AUDIOBOOKS_DST"
              rsync "${RSYNC_OPTS[@]}" "$audiobook_path" "$AUDIOBOOKS_DST/$audiobook_name"
            fi
          fi
        else
          echo "WARNING: Audiobook not found: $audiobook_path"
        fi
      done
      
      # Now remove audiobooks from destination that are not in the selection
      echo "Removing audiobooks not in selection..."
      # Build list of expected paths (relative to AUDIOBOOKS_DST) - only exact paths, no parent dirs
      temp_ab_expected_list=$(mktemp)
      for audiobook_path in "${SELECTED_AUDIOBOOKS[@]}"; do
        if [[ "$audiobook_path" == "$AUDIOBOOKS_DIRECTORY"* ]]; then
          relative_path="${audiobook_path#$AUDIOBOOKS_DIRECTORY}"
          relative_path="${relative_path#/}"
          echo "$relative_path" >> "$temp_ab_expected_list"
        fi
      done
      
      # Find and remove files/directories in destination that are not in expected paths
      if [ -d "$AUDIOBOOKS_DST" ]; then
        temp_ab_remove_list=$(mktemp)
        
        find "$AUDIOBOOKS_DST" \( -type d -o -type f \) | while read -r dest_item; do
          [ "$dest_item" = "$AUDIOBOOKS_DST" ] && continue
          
          # Remove AUDIOBOOKS_DST prefix to get relative path (handle with or without trailing slash)
          ab_dst_normalized="${AUDIOBOOKS_DST%/}"
          relative_item="${dest_item#$ab_dst_normalized/}"
          # If removal didn't work, try with trailing slash
          if [ "$relative_item" = "$dest_item" ]; then
            relative_item="${dest_item#$AUDIOBOOKS_DST}"
            relative_item="${relative_item#/}"
          fi
          found=false
          
          if grep -Fxq "$relative_item" "$temp_ab_expected_list" 2>/dev/null; then
            found=true
          fi
          
          if [ "$found" = false ]; then
            current_relative="$relative_item"
            while [ -n "$current_relative" ] && [ "$current_relative" != "." ]; do
              if grep -Fxq "$current_relative" "$temp_ab_expected_list" 2>/dev/null; then
                found=true
                break
              fi
              current_relative="$(dirname "$current_relative")"
            done
          fi
          
          # Check if this item is inside any expected path (item is a descendant of expected)
          # OR if this item is an ancestor of any expected path (needed for parent directories)
          if [ "$found" = false ] && [ -s "$temp_ab_expected_list" ]; then
            while IFS= read -r expected_path; do
              # Check if relative_item equals expected_path exactly
              if [ "$relative_item" = "$expected_path" ]; then
                found=true
                break
              fi
              # Check if relative_item starts with expected_path/ (item is descendant of expected)
              expected_prefix="${expected_path}/"
              if [ "${relative_item#$expected_prefix}" != "$relative_item" ]; then
                found=true
                break
              fi
              # Check if expected_path starts with relative_item/ (item is ancestor of expected)
              relative_prefix="${relative_item}/"
              if [ "${expected_path#$relative_prefix}" != "$expected_path" ]; then
                found=true
                break
              fi
            done < "$temp_ab_expected_list"
          fi
          
          if [ "$found" = false ]; then
            echo "$dest_item" >> "$temp_ab_remove_list"
          fi
        done
        
        # Remove items not in selection (process in reverse order to remove children before parents)
        if [ -s "$temp_ab_remove_list" ]; then
          sort -r "$temp_ab_remove_list" | while read -r item_to_remove; do
            if [ -e "$item_to_remove" ]; then
              echo "Removing audiobook not in selection: $item_to_remove"
              rm -rf "$item_to_remove"
            fi
          done
        fi
        
        rm -f "$temp_ab_remove_list"
      fi
      
      rm -f "$temp_ab_expected_list"
    fi
  fi
fi

echo
echo "Sync complete."
sync