@echo off

call Status
if %HTDOCS_AT_ROOT% equ 0 (
	call Switch	)
cd %PROJECT_PATH%

powershell -ExecutionPolicy unrestricted -file "%Tiggu%\Script\Publish.ps1"

copy .htaccess public\.htaccess
