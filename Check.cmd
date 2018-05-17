@echo Off

if NOT exist "./Root" (
	set tiggu_check=0
	echo Wrong project directory
	exit
) else (
	if NOT exist "./Config" (
		set tiggu_check=0
		echo Wrong project directory
		exit
	) else (
		set tiggu_check=1
	)
)
