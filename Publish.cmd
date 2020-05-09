@echo off

call Check
call Status
if %HTDOCS_AT_ROOT% equ 0 (
	call Toggle	)
cd %PROJECT_PATH%

powershell -ExecutionPolicy unrestricted -file "%Tiggu%\Script\Publish.ps1"

copy .htaccess public\.htaccess
call post-publish
