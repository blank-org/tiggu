# Parameters
param_mode=$1
eHost=$2
eRoot=$3

echo $param_mode
echo $eHost
Halt=FALSE
export Halt

iRoot="$eRoot/Root/"
mRoot="$eRoot/interim/"
oRoot="$eRoot/public/"

eMode=$param_mode

fileListPath="./Config/File.tsv"
idListPath="./Config/ID.tsv"
renderListPath="./Config/Render.lsv"
urlListPath="./Config/Url.tsv"
scriptListPath="./Config/Script.lsv"

iBaseTemplateFile="Template/Base.php"
oBaseWebFile="index"

jsSourceHashFile="${mRoot}.js-source.sha256"
currentJsSourceHash=$(
    find "$iRoot" -type f -name "*.js" -print0 |
    sort -z |
    xargs -0 -r sha256sum |
    sha256sum |
    cut -d ' ' -f 1
)
previousJsSourceHash=""
[ -f "$jsSourceHashFile" ] && previousJsSourceHash=$(cat "$jsSourceHashFile")

if [ "$currentJsSourceHash" != "$previousJsSourceHash" ]; then
    bJavaScriptChanged=TRUE
else
    bJavaScriptChanged=FALSE
fi

# Initialize arrays
fileList=()
idList=()
urlList=()
scriptList=()

# Read and process fileList
if [ -f $fileListPath ]; then
    IFS=$'\t'
    while read -r line; do
        fileList+=("$line")
    done < <(tail -n +2 $fileListPath)
fi

if [ -f "$renderListPath" ]; then
    while IFS= read -r id || [ -n "$id" ]; do
        id="${id%$'\r'}"
        if [ -n "$id" ] && [[ "$id" != \#* ]]; then
            idList+=("$id")
        fi
    done < "$renderListPath"
elif [ -f "$idListPath" ]; then
    while IFS=$'\t' read -r status id rest; do
        if [ "$status" = "published" ] || [ "$status" = "publish" ]; then
            idList+=("$id")
        fi
    done < <(tail -n +2 "$idListPath")
fi

if [ -f "$urlListPath" ]; then
    while IFS=$'\t' read -r -a row; do
        if [ "${row[0]}" != "``" ]; then
            urlList+=("$(IFS=$'\t'; echo "${row[*]}")")
        fi
    done < <(tail -n +2 "$urlListPath")
fi

if [ -f "$scriptListPath" ]; then
    while IFS= read -r line; do
        scriptList+="$line ";
    done < $scriptListPath
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source $SCRIPT_DIR/api.sh

# Directory creation
[ ! -d $oRoot ] && mkdir -p $oRoot
[ ! -d $mRoot ] && mkdir -p $mRoot

for element in "${fileList[@]}"; do
    # Splitting the element into an array
    IFS=$'\t' read -r -a parts <<< "$element"

    # Joining array elements
    iPath="${parts[0]}${parts[1]}"
    oPath="${parts[2]}${parts[3]}"

    if check "" "$iPath" "$oRoot" "$oPath"; then
        oDir="${oRoot}${parts[2]}"

        # Check if directory exists, if not create it
        [ ! -d "$oDir" ] && mkdir -p "$oDir"

        # Call replace function
        replace "" "${parts[0]}" "${parts[1]}" "$oRoot" "${parts[2]}" "${parts[3]}"
    fi
done

if [ -f "$iBaseTemplateFile" ]; then
    if check "$iRoot" "$iBaseTemplateFile" "$oRoot" "$oBaseWebFile"; then
        bTemplateChanged=TRUE
    else
        bTemplateChanged=FALSE
    fi
else
    bTemplateChanged=TRUE
fi

checkResourceDir() {
    componentDir=$1

    if [ -d "${iRoot}Resource/${componentDir}" ]; then
        [ ! -d "${mRoot}${componentDir}" ] && mkdir -p "${mRoot}${componentDir}"
        [ ! -d "${oRoot}${componentDir}" ] && mkdir -p "${oRoot}${componentDir}"
        return 0
    else
        return 1
    fi
}

for component in "${idList[@]}"; do
    componentC="${component/}"
    componentDir="${component/}"

    if [ -f "${iRoot}HTML/Component/${component}.php" ]; then
        componentFile="HTML/Component/${component}.php"
        if checkResourceDir "$componentDir"; then
            componentC+="/index"
        fi
    elif [ -f "${iRoot}HTML/Component/${component}.html" ]; then
        componentFile="HTML/Component/${component}.html"
        if checkResourceDir "$componentDir"; then
            componentC+="/index"
        fi
    else
        componentC+="/index"
        [ ! -d "${mRoot}${componentDir}" ] && mkdir -p "${mRoot}${componentDir}"
        [ ! -d "${oRoot}${componentDir}" ] && mkdir -p "${oRoot}${componentDir}"

        if [ -f "${iRoot}HTML/Component/${component}/index.php" ]; then
            componentFile="HTML/Component/${component}/index.php"
        else
            componentFile="HTML/Component/${component}/index.html"
        fi
    fi

    componentCJSON="${componentC}.json"

    if check "$iRoot" "$componentFile" "$oRoot" "$componentCJSON"; then
        download "$eHost" "$eMode" "${component}.json" "$mRoot" "$componentCJSON"
        compress_html "$mRoot" "$componentCJSON" "$oRoot" "$componentCJSON"
        bComponentChanged=TRUE
    else
        bComponentChanged=FALSE
    fi

    if [ "$componentC" = "root" ]; then
        componentC="$oBaseWebFile"
    fi

    if [ "$bTemplateChanged" = "TRUE" ] || [ "$bComponentChanged" = "TRUE" ]; then
        echo "$component"
        download "$eHost" "$eMode" "$component" "$mRoot" "${componentC}.html"
        compress_html "$mRoot" "${componentC}.html" "$oRoot" "${componentC}.html"
    fi

done

renderTranslatedComponent() {
    local component=$1
    local lang=$2
    local translatedBase="${iRoot}HTML/Component/${lang}/${component}"
    local componentFile
    local componentOutput="${lang}/${component}"

    if [ -f "${translatedBase}.php" ]; then
        componentFile="${translatedBase}.php"
        if checkResourceDir "$component"; then
            componentOutput+="/index"
        fi
    elif [ -f "${translatedBase}.html" ]; then
        componentFile="${translatedBase}.html"
        if checkResourceDir "$component"; then
            componentOutput+="/index"
        fi
    elif [ -f "${translatedBase}/index.php" ]; then
        componentFile="${translatedBase}/index.php"
        componentOutput+="/index"
    elif [ -f "${translatedBase}/index.html" ]; then
        componentFile="${translatedBase}/index.html"
        componentOutput+="/index"
    else
        echo "Translated component not found: ${lang}/${component}" >&2
        Halt=TRUE
        return 1
    fi

    local jsonOutput="${componentOutput}.json"
    local htmlOutput="${componentOutput}.html"
    mkdir -p "$(dirname "${mRoot}${jsonOutput}")" "$(dirname "${oRoot}${jsonOutput}")"

    local componentChanged=FALSE
    if check "" "$componentFile" "$oRoot" "$jsonOutput"; then
        download "$eHost" "$eMode" "${lang}/${component}.json" "$mRoot" "$jsonOutput" || return 1
        compress_html "$mRoot" "$jsonOutput" "$oRoot" "$jsonOutput" || return 1
        componentChanged=TRUE
    fi

    if [ "$bTemplateChanged" = "TRUE" ] || [ "$componentChanged" = "TRUE" ]; then
        download "$eHost" "$eMode" "${lang}/${component}" "$mRoot" "$htmlOutput" || return 1
        compress_html "$mRoot" "$htmlOutput" "$oRoot" "$htmlOutput" || return 1
    fi
}

translationsListPath="./Config/Translations.tsv"
if [ -f "$translationsListPath" ]; then
    IFS=$'\t' read -r -a translationLanguages < "$translationsListPath"
    while IFS=$'\t' read -r -a translationRow; do
        component="${translationRow[0]%$'\r'}"
        for ((column=1; column<${#translationLanguages[@]}; column++)); do
            lang="${translationLanguages[$column]%$'\r'}"
            translationStatus="${translationRow[$column]%$'\r'}"
            if [ "$lang" != "en" ] && { [ "$translationStatus" = "published" ] || [ "$translationStatus" = "publish" ]; }; then
                renderTranslatedComponent "$component" "$lang" || exit 1
            fi
        done
    done < <(tail -n +2 "$translationsListPath")
fi
processRecord() {

    local _dir_=$1
    local _file_=$2
    local _ext_=$3

    mDir="${mRoot}${_dir_}"
    [ ! -d "$mDir" ] && mkdir -p "$mDir"

    oDir="${oRoot}${_dir_}"
    [ ! -d "$oDir" ] && mkdir -p "$oDir"

    component="${_dir_}${_file_}"

    if [[ "$component" == "root" && -z "${_ext_}" ]]; then
        component=""
        component_full="$oBaseWebFile"
    else
        if [[ -n "${_dir_}" && "${_dir_}" == */ && -z "${_file_}" ]]; then
            component_full="${component}/${oBaseWebFile}"
        else
            component_full="$component"
        fi
    fi


    if [ -z "$_ext_" ]; then
        ext="html"
    else
        ext="$_ext_"
        component="${component}.${ext}"
    fi

    component_full="${component_full/}.${ext}"

    if [[ "$bTemplateChanged" == "TRUE" ||
          ! -f "${oRoot}/${component_full}" ||
          ( "$ext" == "js" && "$bJavaScriptChanged" == "TRUE" ) ]]; then
        echo "${parts[@]}"
        
        download "$eHost" "$eMode" "$component" "$mRoot" "$component_full"
        case "$ext" in
            "html")
                compress_html "$mRoot" "$component_full" "$oRoot" "$component_full"
                ;;
            "css")
                if [[ "${_file_}" == *.min* || -n "${parts[3]}" ]]; then
                    cp "$mRoot/$component_full" "$oRoot/$component_full"
                else
                    compress_css "$mRoot" "$component_full" "$oRoot" "$component_full"
                fi
                ;;
            "js")
                if [[ "${_file_}" == *.min* || -n "${parts[3]}" ]]; then
                    cp "$mRoot/$component_full" "$oRoot/$component_full"
                else
                    compress_js "$mRoot" "$component_full" "$oRoot" "$component_full"
                fi
                ;;
            "json")
                if [[ "${_file_}" == *.min* || -n "${parts[3]}" ]]; then
                    cp "$mRoot/$component_full" "$oRoot/$component_full"
                else
                    compress_json "$mRoot" "$component_full" "$oRoot" "$component_full"
                fi
                ;;
            *)
                cp "$mRoot/$component_full" "$oRoot/$component_full"
                ;;
        esac
    fi

}


# Common assets live in Url.tsv. Language-specific rows live in Url_<lang>.tsv.
urlManifests=("./Config/Url.tsv")
shopt -s nullglob
for extraUrlList in ./Config/Url_*.tsv; do
    urlManifests+=("$extraUrlList")
done

urlNo=0
for urlListPath in "${urlManifests[@]}"; do
    [ -f "$urlListPath" ] || continue
    echo "URL list: $urlListPath"
    header=1
    while IFS= read -r url || [ -n "$url" ]; do
        if [ "$header" -eq 1 ]; then
            header=0
            continue
        fi

        url="${url%$'\r'}"
        [ -z "$url" ] && continue
        urlFields="${url}"$'\t\t'
        urlDir="${urlFields%%$'\t'*}"
        urlFields="${urlFields#*$'\t'}"
        urlFile="${urlFields%%$'\t'*}"
        urlFields="${urlFields#*$'\t'}"
        urlExt="${urlFields%%$'\t'*}"

        urlDir="${urlDir//\\//}"
        urlFile="${urlFile//\\//}"
        urlExt="${urlExt//\\//}"

        ((urlNo++))
        echo "URL: $urlNo"
        processRecord "$urlDir" "$urlFile" "$urlExt"
        ((rowCounter++))
    done < "$urlListPath"
done


exit_check

if [ "$bJavaScriptChanged" = "TRUE" ]; then
    printf '%s\n' "$currentJsSourceHash" > "$jsSourceHashFile"
fi


for script in "${scriptList[@]}"; do
    updateScriptVersion $script
done
