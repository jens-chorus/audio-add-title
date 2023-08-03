#!/bin/sh
case "$(uname -sr)" in

   Darwin*)
     env='OSX'
     echo 'Mac OS X'
     ;;

   Linux*Microsoft*)
     env='WSL'
     echo 'WSL'  # Windows Subsystem for Linux
     ;;

   Linux*)
     env='Linux'
     echo 'Linux'
     ;;

   CYGWIN*|MINGW*|MINGW32*|MSYS*)
     env="MSW"
     echo 'MS Windows'
     ;;

   # Add here more strings to compare
   # See correspondence table at the bottom of this answer

   *)
     echo 'Other OS'
     ;;
esac

case $env in

   OSX)
     speaker = $(echo say -v \? | grep de_DE | awk 'NR==1{print $1}')
     for inputfile in *
     do echo "$inputfile"
     title=$(exiftool -json "$inputfile" | jq -r '.[0].Title') && echo $title && say -v $speaker "$title"  -o title.wav --data-format=LEF32@22050
     ffmpeg -i title.wav -i "$inputfile" -filter_complex "[0:a:0][1:a:0]concat=n=2:v=0:a=1[outa]" -map "[outa]" -map_metadata 1 -ab 128k -ac 2 -ar 44100 "./with-intro/${inputfile%.*}-$title.with_intro.${inputfile##*.}"
     done
   ;;
   Linux)
     for inputfile in /gegebenes/verzeichnis/*
     do echo "$inputfile"
     exiftool -json "$inputfile" | jq '.[0].Title' | espeak -vde -w /tmp/title.wav; ffmpeg -i /tmp/title.wav -i "$inputfile" -filter_complex "[0:a:0][1:a:0]concat=n=2:v=0:a=1[outa]" -map "[outa]" -map_metadata 1 -ab 128k -ac 2 -ar 44100 "${inputfile%.*}.with_intro.${inputfile##*.}"
     done
   ;;
esac




exit 1



