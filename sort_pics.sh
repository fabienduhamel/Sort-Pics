#!/bin/bash

function dir_contains_raw
{
    RAW_FILE_COUNT=`ls | grep ".dng$" | wc -l`
    [[ RAW_FILE_COUNT -gt "0" ]] && echo 1 || echo 0
}

function display
{
    echo -e "$1${NC}"
}

WD=`pwd`
DIR=$WD/$1
OUT_DIR="$DIR/out"
RAW_DIR="$OUT_DIR/raw"
EXPORT_DIR="$OUT_DIR/export"
FILE_SIZE_LIMIT=4194304
FILE_WIDTH_LIMIT=2560

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Wrong args
if [ -z "$1" ]; then
    display "${RED}Missing argument"
    display "Usage:\n\t ${YELLOW}$0 <dir>"
    exit
fi

cd "$DIR"

# Check out dir
if [ -d "$OUT_DIR" ]; then
    display "${RED}Out dir already exists. Clear it before"
    exit 1
else
    mkdir "$OUT_DIR"
    display "${GREEN}$OUT_DIR${NC} created"
fi

# Rename pics to out/
RENAME_TOOL_CMD_LINE="~/dev/Exif-rename/console rename \"$DIR\" \"$OUT_DIR\""
eval $RENAME_TOOL_CMD_LINE

# Move RAW files to raw dir
if [[ `dir_contains_raw` -gt 0 ]]; then
    [ -d "$RAW_DIR" ] && display "Raw dir exists" || mkdir -p "$RAW_DIR"
    display "${GREEN}$RAW_DIR${NC} created"
    mv "$OUT_DIR"/*.dng "$RAW_DIR"
    display "Raw files moved from ${GREEN}$OUT_DIR${NC} to ${GREEN}$RAW_DIR"
else
    display "${GREEN}$DIR${NC} does not contain raw files"
fi

# Rsync files other than JPG/jpg/PNG/png/DNG/dng in main directory to out/
while read file; do
    rsync -a "$file" "$OUT_DIR"
    display "${GREEN}$file${NC} copied to ${GREEN}$OUT_DIR/$file"
done < <(find . -maxdepth 1 -type f | grep -viE "\.(jpg|png|dng)$")

# Rsync dirs to out/
while read dir; do
    rsync -aR "$dir" "$OUT_DIR"
    display "${GREEN}$dir${NC} copied to $OUT_DIR/$dir"
done < <(ls -d */ | grep -vE "^out/$")

# Compress files to export dir
cd "$OUT_DIR"

if [ -d "$EXPORT_DIR" ]; then
    display "${RED}$EXPORT_DIR already exists. Clear it before"
    exit 1
else
    mkdir "$EXPORT_DIR"
    display "${GREEN}$EXPORT_DIR${NC} created"
fi

while read file; do
    FILE_SIZE=`stat --printf="%s" $file`
    FILE_WIDTH=`exiftool $file | grep "Exif Image Width" | cut -d':' -f2 | cut -d' ' -f2`
    if [[ $FILE_SIZE -gt $FILE_SIZE_LIMIT ]]; then
        if [[ $FILE_WIDTH -gt $FILE_WIDTH_LIMIT ]]; then
            convert -quality 90 -resize $FILE_WIDTH_LIMIT "$file" "$EXPORT_DIR/$file"
        else
            convert -quality 90 "$file" "$EXPORT_DIR/$file"
        fi
        display "${GREEN}$file${NC} compressed to ${GREEN}$EXPORT_DIR/$file"
    else
        rsync -a "$file" "$EXPORT_DIR"
        display "${GREEN}$file${NC} copied to ${GREEN}$EXPORT_DIR/$file"
    fi
done < <(find . -maxdepth 1 -type f | grep -iE "\.(jpg)$")
