@ECHO OFF
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

REM
REM Arg 1: Prompt to display before input cursor.
REM

if [%1] == [] (
	set prompt="Input"
) else (
	set prompt=%~1
)
set "masking_command=powershell 2^>^&1 -Command "$pword = read-host '%prompt%' -AsSecureString ; $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pword) ; [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)""

REM https://www.dostips.com/forum/viewtopic.php?p=17949&sid=8dd637ff3cb2aa760536300a629fc3b3#p17949
REM the %%^^errorlevel%%` is basically a trick to postpone variable expansion based on the fact that the expansion result
REM of %var% is %var% if var does not exist.
set masking_command_output_line_count=0
for /F "delims=" %%a in ('%masking_command% ^& call echo %%^^errorlevel%%') do (
   set /A masking_command_output_line_count+=1
   set "masking_command_output_array[!masking_command_output_line_count!]=%%a"
)
REM Final errorlevel is stored in last line, the value the user entered is at index 1.
if !masking_command_output_array[%masking_command_output_line_count%]! gtr 0 (
   echo ERROR: Calling the mask user input functionality caused an error. & goto end_with_error
) else (
   set masked_command_output=!masking_command_output_array[1]!
)
goto end

:end_with_error
endlocal
exit /b 1

:end
REM What follows is a trick to get the variables into the context of the calling script (which should be a local context as well) without polluting the global env.
REM See https://stackoverflow.com/a/16167938
endlocal&set "masked_user_input=%masked_command_output%"