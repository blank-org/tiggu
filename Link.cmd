@echo Off

set PROJECT_PATH=%CD%
cd /d %ProgramData%\Apache\HTTPD

rd htdocs
mklink /j htdocs "%PROJECT_PATH%\%target%" > nul
