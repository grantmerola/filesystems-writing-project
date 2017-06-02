# !bin/bash
slimrb -p filesystems.slim > index.html
markdown filesystems.md > filesystems.html
sed -i '' -e '/REPLACE/r filesystems.html' -e '/REPLACE/d' index.html
#open -a "Google Chrome" index.html
