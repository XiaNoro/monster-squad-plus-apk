@echo off
rem Usage: cube_demo.bat [count] [red^|yellow^|blue^|pet^|pet_rare]
set COUNT=%1
if "%COUNT%"=="" set COUNT=11
set KIND=%2
if "%KIND%"=="" set KIND=red
cd /d "%~dp0.."
start "" "E:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --path . -- --test-save --test-script=res://tests/cube_demo.gd --cubes=%COUNT% --kind=%KIND%
