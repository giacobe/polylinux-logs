#!/bin/sh
PS1='\W$ '
cd "$HOME" || exit 1
clear
echo "************************************************************************"
echo "* PolyLinux System Information and Logs                                *"
echo "* This Buildroot VM is a collection console. Evidence describes       *"
echo "* remote Linux hosts. Read README.txt to begin.                        *"
echo "* Submit one answer per level. Move with nextlevel and prevlevel.      *"
echo "************************************************************************"
echo "* Level: $USER"
cat README.txt

