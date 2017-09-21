#!/bin/bash
declare -a packages=("ffmpeg" "convert" "apngasm" "pngnq-s9" "mediainfo");
declare -a packmans=("apt-get" "yum" "dnf" "pacman");

#set -v -x
declare -x colors
canvaswidth=1232
canvasheight=256
cwd=$(pwd)
padding=20
framewidth=300
rowno=3
eachrow=3
lenghtsec=1.5
fps=10


math ()
{
canvaswidth=$((padding+(padding*eachrow)+(eachrow*framewidth)))
noframes=$((rowno*eachrow))
frameheight=$(echo "$framewidth / 1.77777" | bc)
canvasheight=$((padding+(padding*rowno)+(rowno*frameheight)))
}
math

install ()
{
if [ "$(whoami)" != "root" ]; then
	echo "Have to run installation as root"
	exit
fi
for i in "${packmans[@]}"; do
	if command -v "$i" 2>/dev/null; then
		packetman=$i
	fi
done
if [ "$packetman" == "" ]; then
	echo "Can't find your packetmanager!"
	exit
fi
echo "Running $packetman update"
$packetman update &> /dev/null
echo "Checking for prerequsites"
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
				$packetman -y install imagemagick
				else
				if [[ $i == "apngasm" ]]
					then
					wget -P /tmp/ "https://downloads.sourceforge.net/project/apngasm/2.91/apngasm-2.91-bin-linux.zip"
					unzip -x /tmp/apngasm-2.91-bin-linux.zip -d /tmp/
					mv /tmp/apngasm /usr/local/bin/
					rm -rf /tmp/apngasm-2.91-bin-linux.zip /tmp/readme.txt
					else
					if [[ $i == "pngnq-s9" ]]
						then
							if [[ $(ldconfig -p | grep libpng16.so.16) == "" ]]
								then
								$packetman -y install libpng16-16
							fi
							wget -P /tmp/ "https://downloads.sourceforge.net/project/pngnqs9/pngnq-s9-2.0.2.tar.gz"
							tar -xzf /tmp/pngnq-s9-2.0.2.tar.gz -C /tmp/
							/tmp/pngnq-s9-2.0.2/configure
							make /tmp/pngnq-s9-2.0.2
							make install /tmp/pngnq-s9-2.0.2
							rm -rf /tmp/pngnq-s9-2.0.2
							rm -rf /tmp/pngnq-s9-2.0.2.tar.gz
						else
							$packetman -y install "$i" 
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


if (($# < 1)); then
	echo "Only give me one file."
	exit
fi
test=$(mediainfo --Inform="General;%Duration%" "${@: -1}")
if [ "$test" == "" ]; then
	echo "I need a videooooo"
	exit
fi


reducesize ()
{
echo "Reducing size based on colors"
framedir=$(basename "$@")
pngnq-s9 -d "$@" -e .png -f -n "$colors" "$*"*.png
apngasm "$cwd/$OUTPUT.png" "$*"*.png 1 10 -z2 -i1 &> /dev/null
size=$(stat -c%s "$cwd/$OUTPUT.png")
if [ "$size" -gt 3099999 ]; then
	echo "Reducing size"
	colors=$((colors - 20))
	reducesize "$@"
fi
}

grabvideo ()
{
echo "Grabbing frames from file"
OUTPUT=$(basename "${@: -1}")
mkdir /tmp/grabs  2>/dev/null
lenght=$(mediainfo --Inform="General;%Duration%" "$1")
lenght=$((lenght/1000))
for ((n=1;n<noframes+1;n++)); do
	mkdir /tmp/grabs/$n 2>/dev/null
	ffmpeg -v error -ss $(( lenght * n / (noframes+1) )) -t $lenghtsec -i "$1" -r $fps -vf "scale=$framewidth:-1" /tmp/grabs/$n/out%03d.png
done
for p in /tmp/grabs/1/*; do
		pics+=("$p")
	done
mkdir /tmp/frame 2>/dev/null
}
makegif ()
{
echo "Arranging frames"
for n in "${pics[@]}"; do
	nu=$(basename "$n")
	#cp $pngframe "/tmp/frame/frame$nu"
	convert -size "$canvaswidth"x"$canvasheight" xc:"rgba(0,0,0,0)" PNG32:/tmp/frame/frame"$nu"
	cur=0
	for ((rn=0;rn<rowno;rn++)); do
		for ((i=0;i<eachrow;i++)); do
			composite -geometry +$((padding+framewidth*i+padding*i))+$((padding+frameheight*rn+padding*rn)) "/tmp/grabs/$((cur+1))/$nu" "/tmp/frame/frame$nu" "/tmp/frame/frame$nu"
			cur=$((cur+1))
		done
	done
	#convert "/tmp/frame/frame$nu" -gravity center -pointsize 30  -stroke '#000C' -strokewidth 2 -annotate 0 "$base" -pointsize 30 -stroke none -fill white -annotate 0 "$base" -depth 8 /tmp/frame/frame$nu
	mogrify -path /tmp/frame/ -filter Triangle -define filter:support=2 -thumbnail 1100 -unsharp 0.25x0.08+8.3+0.045 -dither None -posterize 136 -quality 82 -define jpeg:fancy-upsampling=off -define png:compression-filter=5 -define png:compression-level=9 -define png:compression-strategy=1 -define png:exclude-chunk=all -interlace none -colorspace sRGB /tmp/frame/frame"$nu"
done
reducesize /tmp/frame/
rm -rf /tmp/grabs
rm -rf /tmp/frame
echo "Done"
}

math
if ((noframes > 6)); then
	colors=80
	else
	colors=190
fi
grabvideo "${@: -1}"
makegif 
