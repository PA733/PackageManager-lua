@ECHO OFF

REM Set environment variables
SET PATH=%PATH%;%~dp0;%~dp0lib
SET LUA_PATH=%~dp0?.lua;%~dp0share\?.lua;%~dp0share\json\?.lua
SET LUA_CPATH=%~dp0lib\?.dll

REM Run Run.lua with the arguments passed to this script
%~dp0runtime\lua-5.4.2_Win64_bin\lua54 %~dp0Run.lua %*