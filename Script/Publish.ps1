$global:Halt = $FALSE

$iRoot = "Root\"
$oRoot = "public\"
$mRoot = "interim\"

$eHost = "http://localhost"
$eMode = "mode=publish"

$fileListPath = ".\Config\File.tsv" 	#File List
$idListPath = ".\Config\ID.tsv"   	#ID List
#$tlPath = ".\Config\Template.tsv"	#Template List
$urlListPath = ".\Config\URL.tsv"	#URL List

$iBaseTemplateFile = "Template\Base.php"
$oBaseWebFile = "index"
# Could be tested against any other 'Snapped' file

$fileList = @()
$idList = @()
$urlList = @()

if ((Test-Path $fileListPath) -eq $TRUE) {
	$fileListC = GC $fileListPath | select-object -skip 1
	foreach ($e in $fileListC) {
		$fileList += ,($e.Split("`t", [StringSplitOptions]'RemoveEmptyEntries'))
	}
}

if ((Test-Path $idListPath) -eq $TRUE) {
	$idListC = GC $idListPath | select-object -skip 1
	foreach ($e in $idListC) {
		$id = ($e.Split("`t"))[0]
		if($id -ne "#") {
			$idList += $id
		}
	}
}

if ((Test-Path $urlListPath) -eq $TRUE) {
	$urlListC = GC $urlListPath | select-object -skip 1
	foreach ($e in $urlListC) {
		$row = ($e.Split("`t"))
		if($row[0] -ne "``") {
			$urlList += ,$row
		}
	}
}

. "$Env:TIGGU\Script\API.ps1"

if ((Test-Path $oRoot) -ne $TRUE) {
	New-Item -ItemType directory -Path $oRoot
}
if ((Test-Path $mRoot) -ne $TRUE) {
	New-Item -ItemType directory -Path $mRoot
}

foreach ($element in $fileList) {
	if (Check "" ($element[0..1] -join '') $oRoot ($element[2..3] -join '')) {
		$oDir = $oRoot, $element[2] -join ''
		if ((Test-Path $oDir) -ne $TRUE) {
			New-Item -ItemType directory -Path $oDir
		}
		Replace "" $element[0] $element[1] $oRoot $element[2] $element[3]
	}
}

if((Test-Path $iBaseTemplateFile) -eq $TRUE) {
#$tList = GC $tlPath
#foreach ($element in $tList) {
	if (Check $iRoot $iBaseTemplateFile $oRoot $oBaseWebFile) {
		$bTemplateChanged = $TRUE
#		break
	}
	else {
		$bTemplateChanged = $FALSE
	}
#}
}
#else
#	$bTemplateChanged = $TRUE
#}

function checkResourceDir {
	if((Test-Path $iRoot"Resource\$componentDir") -eq $TRUE ) {
		if ((Test-Path $mRoot$componentDir) -ne $TRUE) {
			New-Item -ItemType directory -Path $mRoot$componentDir
		}
		if ((Test-Path $oRoot$componentDir) -ne $TRUE) {
			New-Item -ItemType directory -Path $oRoot$componentDir
		}
		return $TRUE
	}
	else {
		return $FALSE
	}
}

foreach ($component in $idList) {

	$componentC = $component -replace "/","\"
	$componentDir = $component -replace "/","\"

	if((Test-Path $iRoot"HTML\Component\$component.php") -eq $TRUE ) {
		$componentFile = "HTML\Component\$component.php"
		if(checkResourceDir -eq $TRUE ) {
			$componentC += "\index"
		}
	}
	else {
		if((Test-Path $iRoot"HTML\Component\$component.html") -eq $TRUE ) {
			$componentFile = "HTML\Component\$component.html"
			if(checkResourceDir -eq $TRUE ) {
				$componentC += "\index"
			}
		}
		else {
			$componentC += "\index"
			if ((Test-Path $mRoot$componentDir) -ne $TRUE) {
				New-Item -ItemType directory -Path $mRoot$componentDir
			}
			if ((Test-Path $oRoot$componentDir) -ne $TRUE) {
				New-Item -ItemType directory -Path $oRoot$componentDir
			}

			if((Test-Path $iRoot"HTML\Component\$component\index.php") -eq $TRUE ) {
				$componentFile = "HTML\Component\$component\index.php"
			}
			else {
				$componentFile = "HTML\Component\$component\index.html"
			}
		}
	}

	$componentCJSON = "$componentC.json"

	if (Check $iRoot $componentFile $oRoot $componentCJSON) {
		Download $eHost $eMode "$component.json" $mRoot $componentCJSON
		CompressHtml $mRoot $componentCJSON $oRoot $componentCJSON
		$bComponentChanged = $TRUE;
	}
	else {
		$bComponentChanged = $FALSE;
	}

	if ($componentC -eq "root") {
		$componentC = $oBaseWebFile;
	}
	
	if (($bTemplateChanged -eq $TRUE) -or ($bComponentChanged -eq $TRUE)) {
		Write-Host $component
		Download $eHost $eMode $component $mRoot "$componentC.html"
		CompressHtml $mRoot "$componentC.html" $oRoot "$componentC.html"
	}

}

foreach ($element in $urlList) {
	Write-Host $element

	$mDir = $mRoot, $element[0] -join ''
	if ((Test-Path $mDir) -ne $TRUE) {
		New-Item -ItemType directory -Path $mDir
	}
	$oDir = $oRoot, $element[0] -join ''
	if ((Test-Path $oDir) -ne $TRUE) {
		New-Item -ItemType directory -Path $oDir
	}

	$component = $element[0], $element[1] -join ''
	if ($component -eq "root") {
		$component = ""
		$component_full = $oBaseWebFile;
	}
	else {
		if($element[0] -ne "" -and $element[0].EndsWith("/") -and $element[1] -eq "") {
			$component_full = "$component\$oBaseWebFile";
		}
		else {
			$component_full = $component;
		}
	}
	if ($element[2] -eq "") {
		$ext = "html"
	}
	else {
		$ext = $element[2]
		$component = "$component.$ext"
	}
	
	$component_full = $component_full.replace("/", "\");
	$component_full = "$component_full.$ext"
	
	if (($bTemplateChanged -eq $TRUE) -or ((Test-Path $oRoot\$component_full) -ne $TRUE)) {
	
		Download $eHost $eMode $component $mRoot $component_full
		if ($ext -eq "html") {
			CompressHtml $mRoot $component_full $oRoot $component_full
		}
		elseif ($ext -eq "css") {
			if ($element[1].EndsWith(".min") -or $element[3] -ne $NULL) {
				Copy-Item "$mRoot/$component_full" "$oRoot/$component_full"
			}
			else {
				CompressCss $mRoot $component_full $oRoot $component_full
			}
		}
		elseif ($ext -eq "js") {
			if ($element[1].EndsWith(".min") -or $element[3] -ne $NULL) {
				Copy-Item "$mRoot/$component_full" "$oRoot/$component_full"
			}
			else {
				CompressJs $mRoot $component_full $oRoot $component_full
			}
		}
		elseif ($ext -eq "json") {
			if ($element[1].EndsWith(".min") -or $element[3] -ne $NULL) {
				Copy-Item "$mRoot/$component_full" "$oRoot/$component_full"
			}
			else {
				CompressJson $mRoot $component_full $oRoot $component_full
			}
		}
		else {
			Copy-Item "$mRoot/$component_full" "$oRoot/$component_full"
		}
		
	}
	
}

XExit
