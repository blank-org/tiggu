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
urlListPath="./Config/URL.tsv"
scriptListPath="./Config/Script.lsv"

iBaseTemplateFile="Template/Base.php"
oBaseWebFile="index"

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

if [ -f "$idListPath" ]; then
    while IFS=$'\t' read -r id rest; do
        if [ "$id" != "#" ]; then
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

    if [[ "$bTemplateChanged" == "TRUE" || ! -f "${oRoot}/${component_full}" ]]; then
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


# Read the TSV file line by line
urlNo=-1
urlList=$(tr '\t' ',' < $urlListPath)
for url in $urlList; do
    ((urlNo++))
    # Skip the first line
    if [ "$urlNo" -eq 0 ]; then
        continue
    fi
    echo "URL: $urlNo"
    IFS=',' read -r -a col <<< "$url"
    processRecord "${col[0]}" "${col[1]}" "${col[2]}"
    ((rowCounter++))
done


exit_check


for script in "${scriptList[@]}"; do
    updateScriptVersion $script
done
