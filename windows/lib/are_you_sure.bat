@ECHO OFF
set "answerisyes="
set "answerisno="
set "entered_value="
set /p entered_value="%~1 (y/[n])? "
if /I "!entered_value!" EQU "y" (
	set "answerisyes=y"
	set "answerisno="
) else (
	set "answerisyes="
	set "answerisno=y"
)
