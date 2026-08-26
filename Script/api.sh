check() {
    local iRoot=$1
    local i=$2
    local oRoot=$3
    local o=$4

    if [ ! -f "$iRoot$i" ]; then
        echo "Input file: $iRoot$i not found. Fatal Error!"
        Halt=TRUE
        exit -1
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
    local requestHost="${TIGGU_ORIGIN:-$eHost}"
    local hostHeader="${TIGGU_HOST_HEADER:-}"

    if command -v wget >/dev/null 2>&1; then
        if [ -n "$hostHeader" ]; then
            wget --header="Host: $hostHeader" "$requestHost/$i?mode=$eMode" -O "$oRoot$o"
        else
            wget "$requestHost/$i?mode=$eMode" -O "$oRoot$o"
        fi
    else
        if [ -n "$hostHeader" ]; then
            curl -fsSL --retry 5 --retry-all-errors --retry-delay 1 \
                -H "Host: $hostHeader" "$requestHost/$i?mode=$eMode" -o "$oRoot$o"
        else
            curl -kfsSL --retry 5 --retry-all-errors --retry-delay 1 \
                "$requestHost/$i?mode=$eMode" -o "$oRoot$o"
        fi
    fi
    local command_status=$?
    status "$command_status"
    return "$command_status"
}


compress_html() {
    local iRoot=$1
    local i=$2
    local oRoot=$3
    local o=$4
    "${TIGGU_MINIFY:-minify}" -o "$oRoot$o" "$iRoot$i"

    local command_status=$?
    status "$command_status"
    return "$command_status"
}


compress_js() {
    local iRoot=$1
    local i=$2
    local oRoot=$3
    local o=$4

    "${TIGGU_JAVA:-java}" -jar "${TIGGU_CLOSURE_JAR:-/usr/local/lib/gclosure/closure-compiler.jar}" --js "$iRoot$i" --js_output_file "$oRoot$o" --create_source_map "$oRoot$o.map" --source_map_location_mapping "./interim/|/"
    local command_status=$?
    status "$command_status"
    return "$command_status"
}


compress_css() {
    local iRoot=$1
    local i=$2
    local oRoot=$3
    local o=$4

    "${TIGGU_MINIFY:-minify}" -o "$oRoot$o" "$iRoot$i"
    local command_status=$?
    status "$command_status"
    return "$command_status"
}


compress_json() {
    local iRoot=$1
    local i=$2
    local oRoot=$3
    local o=$4

    "${TIGGU_MINIFY:-minify}" -o "$oRoot$o" "$iRoot$i"
    local command_status=$?
    status "$command_status"
    return "$command_status"
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
        exit 1
    else
        echo "All files are up to date."
    fi
}


updateScriptVersionRef() {
    local scriptName="$1"
    local crc="$2"
    local match_files="$3"

    local pattern="/$scriptName(-[0-9]+\.min)?\.js"
    if [ "$bJavaScriptChanged" = "TRUE" ]; then
        grep -RIlZE \
            --include="$match_files" \
            --exclude-dir='.git' \
            "$pattern" \
            "$eRoot/public/"
    else
        find "$eRoot/public/" -type f -name "$match_files" \
            -newer "$buildMarker" -print0 | \
            xargs -0 -r grep -IlZE "$pattern"
    fi | xargs -0 -r sed -E -i \
        "s|$pattern|/$scriptName-$crc.min.js|g"
}


updateScriptVersion() {
    local scriptName="$1"

    # Incremental builds may not recreate the public intermediate after the
    # previous build moved it to its cache-busted production name.
    if [ ! -f "$eRoot/public/$scriptName.js" ]; then
        compress_js "$mRoot" "$scriptName.js" "$eRoot/public/" "$scriptName.js"
    fi

    local crc=$(cksum "$eRoot/public/$scriptName.js" | cut -d ' ' -f 1)
    find "$eRoot/public/" -maxdepth 1 -type f \
        \( -name "$scriptName-*.min.js" -o -name "$scriptName-*.min.js.map" \) \
        -delete
    # Keep the unhashed name so pages still requesting /script.js do not 404
    # if HTML rewrite misses them. Cache-busted copies are for rewritten HTML.
    cp "$eRoot/public/$scriptName.js" "$eRoot/public/$scriptName-$crc.min.js"
    cp "$eRoot/public/$scriptName.js.map" "$eRoot/public/$scriptName-$crc.min.js.map"
    # append map file path to the end of the script file
    echo "//# sourceMappingURL=/$scriptName-$crc.min.js.map" >> "$eRoot/public/$scriptName-$crc.min.js"

    updateScriptVersionRef "$scriptName" "$crc" "*.html"
    updateScriptVersionRef "$scriptName" "$crc" "sw.js"
}
