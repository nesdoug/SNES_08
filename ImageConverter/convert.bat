@echo off

set name="spacebar"

superfamiconv -B 2 -i %name%.png -p %name%.pal -t %name%.chr -m %name%.map

pause
