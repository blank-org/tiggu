@echo off

call Check

call Status
cd %PROJECT_PATH%

if exist "./Config/Project.ini" (
	set /p ehost=<./Config/Project.ini
) else (
	set ehost="http://localhost"
	if %HTDOCS_AT_ROOT% equ 0 (
		call Toggle
		cd %PROJECT_PATH%
	)
)

powershell -ExecutionPolicy unrestricted -file "%Tiggu%\Script\Publish.ps1" %1 %ehost%

copy .htaccess public\.htaccess
call post-publish
