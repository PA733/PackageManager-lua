@ECHO OFF

REM Add ./lib and ./runtime/lua-5.4.2_Win64_bin to PATH

SET PATH=%PATH%;%~dp0lib;%~dp0runtime\lua-5.4.2_Win64_bin

REM Run Run.lua with the arguments passed to this script

lua54 %~dp0Run.lua %*