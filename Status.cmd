@echo Off

set PROJECT_PATH=%CD%

cd /d %ProgramFiles%\Apache\HTTPD

@dir htdocs? | find /i "%PROJECT_PATH%" > nul
if errorLevel 1 (
	dir htdocs? | find /i "htdocs"
	set HTDOCS_AT_ROOT=0
) else (
	dir "%ProgramFiles%\Apache\HTTPD\htdocs"? | find /i "%PROJECT_PATH%\public" > nul
	if errorLevel 1 (
		echo Root
		set HTDOCS_AT_ROOT=1
	) else (
		echo public
		set HTDOCS_AT_ROOT=0
	)
)

ping -n 3 localhost > nul
