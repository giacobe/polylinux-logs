#!/bin/sh
. /etc/profile.d/polylinux-colors.sh
PS1='\W$ '
cd "$HOME" || exit 1
clear
box_line() { printf '* %-36.36s *\n' "$1"; }
echo '****************************************'
box_line 'PolyLinux: System Info and Logs'
box_line 'Read README.txt to begin.'
box_line 'Submit answers to the exercise'
box_line 'grading form.'
box_line 'Use nextlevel and prevlevel.'
echo '****************************************'
cat README.txt
