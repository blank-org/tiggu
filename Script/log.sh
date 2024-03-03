nPhpLogLines=$(wc -l < "$PHP/logs/errors.log")
nHttpdLogLines=$(wc -l < "$httpd/logs/error.log")


# New lines in PHP log
currentPhpLogLines=$(wc -l < "${PHP}/logs/errors.log")
newPhpLogLines=$((currentPhpLogLines - nPhpLogLines))
tail -n "$newPhpLogLines" "${PHP}/logs/errors.log"
nPhpLogLines=$currentPhpLogLines
echo "-----------------------------------------------------------------------------------"


# New lines in Httpd log
currentHttpdLogLines=$(wc -l < "${httpd}/logs/error.log")
newHttpdLogLines=$((currentHttpdLogLines - nHttpdLogLines))
tail -n "$newHttpdLogLines" "${httpd}/logs/error.log"
nHttpdLogLines=$currentHttpdLogLines
