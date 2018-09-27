@echo Off
call Check
powershell "Get-ChildItem .\interim -exclude .git | Remove-Item -recurse"
powershell "Remove-Item -recurse .\public\*"
