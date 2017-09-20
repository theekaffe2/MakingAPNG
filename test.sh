#!/bin/bash
declare -a packages=("ffmpeg" "convert" "apngasm" "pngnq-s9" "mediainfo"); #"libpng16-16"
#set -v -x
canvaswidth=1232
canvasheight=256
cwd=$(pwd)
padding=20
framewidth=384
noframes=3
lenghtsec=1.5
fps=10

math ()
{
canvaswidth=$((padding+(padding*noframes)+(noframes*framewidth)))
}
math

install ()
{
for i in "${packages[@]}"; do
	if command -v "$i" 2>/dev/null 
	then
		echo "$i is installed"
	else 
		echo "$i is not installed"
		read -p  "Would you like to install $i? It is required to run this script. (y/n) " -n 1 -r
		echo   
		if [[ $REPLY =~ ^[Yy]$ ]]
		then
			if [[ $i == "convert" ]]
				then
				sudo apt-get -s --show-progress -y install imagemagick
				else
				if [[ $i == "apngasm" ]]
					then
					wget -P /tmp/ "https://downloads.sourceforge.net/project/apngasm/2.91/apngasm-2.91-bin-linux.zip"
					unzip -x /tmp/apngasm-2.91-bin-linux.zip -d /tmp/
					sudo mv /tmp/apngasm /usr/local/bin/
					rm -rf /tmp/apngasm-2.91-bin-linux.zip /tmp/readme.txt
					else
					if [[ $i == "pngnq-s9" ]]
						then
							if [[ $(ldconfig -p | grep libpng16.so.16) == "" ]]
								then
								sudo apt-get -s --show-progress -y install libpng16-16
							fi
							wget -P /tmp/ "https://downloads.sourceforge.net/project/pngnqs9/pngnq-s9-2.0.2.tar.gz"
							tar -xzf /tmp/pngnq-s9-2.0.2.tar.gz -C /tmp/
							/tmp/pngnq-s9-2.0.2/configure
							make /tmp/pngnq-s9-2.0.2
							sudo make install /tmp/pngnq-s9-2.0.2
							rm -rf /tmp/pngnq-s9-2.0.2
							rm -rf /tmp/pngnq-s9-2.0.2.tar.gz
						else
							sudo apt-get -s --show-progress -y install "$i" 
					fi
				fi
			fi	
			
		else
			echo "Your pressed \"$REPLY\""
			echo "Exiting"
			exit
		fi
	fi
done
exit
}

while getopts ":z" opt; do
	case $opt in
		z)
			install
			;;
		\?)
			echo "Invalid option: -$OPTARG"
			exit
			;;
	esac
done

reducesize ()
{
framedir=$(basename "$@")
pngnq-s9 -d "$@" -e .png -f -n "$colors" "$*"*.png
apngasm "$cwd/$framedir.png" "$*"*.png 1 10 -z2 -i1 &> /dev/null
size=$(stat -c%s "$cwd/$framedir.png")
if [ "$size" -gt 3099999 ]; then
	colors=$((colors - 20))
	reducesize "$@"
fi
}

makegif ()
{
echo "Give me a sec"
mkdir /tmp/grabs
lenght=$(mediainfo --Inform="General;%Duration%" "$1")
lenght=$((lenght/1000))
for ((n=1;n<noframes+1;n++)); do
	mkdir /tmp/grabs/$n
	ffmpeg -v error -ss $(( lenght * n / (noframes+1) )) -t $lenghtsec -i "$1" -r $fps -vf "scale=$framewidth:-1" /tmp/grabs/$n/out%03d.png
done
for p in /tmp/grabs/1/*; do
		pics+=("$p")
	done
mkdir /tmp/frame
for n in "${pics[@]}"; do
	nu=$(basename "$n")
	#cp $pngframe "/tmp/frame/frame$nu"
	convert -size "$canvaswidth"x"$canvasheight" xc:"rgba(0,0,0,0)" PNG32:/tmp/frame/frame"$nu"
	composite -geometry +20+20 "/tmp/grabs/1/$nu" "/tmp/frame/frame$nu" "/tmp/frame/frame$nu"
	composite -geometry +424+20 "/tmp/grabs/2/$nu" "/tmp/frame/frame$nu" "/tmp/frame/frame$nu"
	composite -geometry +828+20 "/tmp/grabs/3/$nu" "/tmp/frame/frame$nu" "/tmp/frame/frame$nu"
	#composite -geometry +21+304 "/tmp/grabs/4/$nu" "/tmp/frame/frame$nu" "/tmp/frame/frame$nu"
	#composite -geometry +325+304 "/tmp/grabs/5/$nu" "/tmp/frame/frame$nu" "/tmp/frame/frame$nu"
	#composite -geometry +641+304 "/tmp/grabs/6/$nu" "/tmp/frame/frame$nu" "/tmp/frame/frame$nu"
	#convert "/tmp/frame/frame$nu" -gravity center -pointsize 30  -stroke '#000C' -strokewidth 2 -annotate 0 "$base" -pointsize 30 -stroke none -fill white -annotate 0 "$base" -depth 8 /tmp/frame/frame$nu
	mogrify -path /tmp/frame/ -filter Triangle -define filter:support=2 -thumbnail 1100 -unsharp 0.25x0.08+8.3+0.045 -dither None -posterize 136 -quality 82 -define jpeg:fancy-upsampling=off -define png:compression-filter=5 -define png:compression-level=9 -define png:compression-strategy=1 -define png:exclude-chunk=all -interlace none -colorspace sRGB /tmp/frame/frame"$nu"
done
colors=190
reducesize /tmp/frame/
rm -rf /tmp/grabs
rm -rf /tmp/frame
echo "Done"
}

math
makegif "${@: -1}"