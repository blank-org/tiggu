check() {
    local iRoot=$1
    local i=$2
    local oRoot=$3
    local o=$4

    if [ ! -f "$iRoot$i" ]; then
        echo "Input file: $iRoot$i not found. Fatal Error!"
        Halt=TRUE
        xexit
        return
    fi

    if [ -f "$oRoot$o" ]; then
        if [ "$(stat -c %Y "$oRoot$o")" -ge "$(stat -c %Y "$iRoot$i")" ]; then
            return 0
        fi
    fi

    echo "$o"
    return 0
}


check_all() {
    local iRoot=$1
    local iDir=$2
    local oRoot=$3
    local o=$4

    for filePath in "$iRoot$iDir"/*; do
        if check "" "$filePath" "$oRoot" "$o"; then
            return 0
        fi
    done

    return 1
}


replace() {
    local iRoot=$1
    local iDir=$2
    local i=$3
    local oRoot=$4
    local oDir=$5
    local o=$6

    if [ -f "$oRoot$oDir$o" ]; then
        rm "$oRoot$oDir$o"
    fi

    cp "$iRoot$iDir$i" "$oRoot$oDir"
    mv "$oRoot$oDir$i" "$oRoot$oDir$o"
}


download() {
    local eHost=$1
    local eMode=$2
    local i=$3
    local oRoot=$4
    local o=$5

    wget "$eHost/$i?mode=$eMode" -O "$oRoot$o"
    status=$?
    echo $status
}


compress_html() {
    local iRoot=$1
    local i=$2
    local oRoot=$3
    local o=$4
    minify -o "$oRoot$o" "$iRoot$i"

    status=$?
    echo $status
}


compress_js() {
    local iRoot=$1
    local i=$2
    local oRoot=$3
    local o=$4

    java -jar ../../project/gclosure/closure-compiler.jar --js "$iRoot$i" --js_output_file "$oRoot$o" --create_source_map "$oRoot$o.map" --source_map_location_mapping "./interim/|/"
    status=$?
    echo $status
}


compress_css() {
    local iRoot=$1
    local i=$2
    local oRoot=$3
    local o=$4

    minify -o "$oRoot$o" "$iRoot$i"
    status=$?
    echo $status
}


compress_json() {
    local iRoot=$1
    local i=$2
    local oRoot=$3
    local o=$4

    minify -o "$oRoot$o" "$iRoot$i"
    status=$?
    echo $status
}


status() {
    success=$1
    if [ "$Halt" = "FALSE" ]; then
        if [ "$success" -ne 0 ]; then
            Halt=TRUE
        fi
    fi
}


exit_check() {
    if [ "$Halt" = "TRUE" ]; then
        read -rsp "Press any key to continue..." -n1 key
        echo
        exit 1
    else
        echo "All files are up to date."
    fi
}


updateScriptVersionRef() {
    local scriptName="$1"
    local crc="$2"
    local match_files="$3"

    find "$eRoot/public/" -type f -name $match_files \
    ! -path '*/.git/*' \
    -exec grep -l "/$scriptName.js" {} \; | \
    while read -r file; do \
        sed -i "s|/$scriptName.js|/$scriptName-$crc.min.js|g" "$file"; \
    done
}


updateScriptVersion() {
    local scriptName="$1"

    local crc=$(cksum "$eRoot/public/$scriptName.js" | cut -d ' ' -f 1)
    cp "$eRoot/public/$scriptName.js" "$eRoot/public/$scriptName-$crc.min.js"
    mv "$eRoot/public/$scriptName.js.map" "$eRoot/public/$scriptName-$crc.min.js.map"
    # append map file path to the end of the script file
    echo "//# sourceMappingURL=/$scriptName-$crc.min.js.map" >> "$eRoot/public/$scriptName-$crc.min.js"

    updateScriptVersionRef "$scriptName" "$crc" "*.html"
    updateScriptVersionRef "$scriptName" "$crc" "sw.js"
}
