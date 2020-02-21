@ECHO OFF
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

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
REM What follows is a trick to get the variables into the context of the calling script (which should be a local context as well) without polluting the global env.
REM See https://stackoverflow.com/a/16167938
endlocal&set "answerisyes=%answerisyes%"&set "answerisno=%answerisno%"
