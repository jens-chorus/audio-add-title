#!/bin/bash
shopt -s extglob

#Define supported audio formats
audio_formats=("mp3" "mp4" "wav" "flac" "aac" "ogg")

readonly ENV_OSX='Mac OS X'
readonly ENV_LINUX='Linux'

print_error() {
  echo "$*" >&2
}

detect_environment() {
  raw_env="$(uname -sr)"
  case ${raw_env} in
    Darwin*)
      echo "${ENV_OSX}"
      ;;
    # Linux*Microsoft*)
    #   env='WSL' # Windows Subsystem for Linux
    #   ;;
    Linux*)
      echo "${ENV_LINUX}"
      ;;
    # CYGWIN* | MINGW* | MINGW32* | MSYS*)
    #   env="MSW"
    #   ;;
    *)
      print_error "Detected unsupported environment: ${raw_env}"
      exit 0
      ;;
  esac
}

get_exif_metadata() {
  #echo $(exiftool -json "$inputfile")
  title=$(exiftool -json "$inputfile" | jq -r '.[0].Title')
  file_name=$(exiftool -json "$inputfile" | jq -r '.[0].FileName')
  file_type_extension=$(exiftool -json "$inputfile" | jq -r '.[0].FileTypeExtension')
  filename_without_ext="${file_name%.*}"
  sanitized_filename_without_ext=$(echo "$filename_without_ext" | iconv -f utf8 -t ascii//TRANSLIT | sed 's/[^a-zA-Z0-9]//g')
  sanitized_filename_with_ext="${sanitized_filename_without_ext}.${file_type_extension}"
  file_sample_rate=$(exiftool -json "$inputfile" | jq -r '.[0].SampleRate')
  file_kbit_rate=$(exiftool -json "$inputfile" | jq -r '.[0].AudioBitrate' | awk 'NR==1{print $1}')
  file_bit_rate=$(($file_kbit_rate * 1000))
}

env="$(detect_environment)"

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --locale)
      locale="$2"
      shift
      ;;
  esac
  shift
done

if [ -z ${locale+x} ]; then
  locale="de_DE"
fi

case $env in
  ${ENV_OSX})
    speaker=$(say -v \? | grep "$locale" | awk 'NR==1{print $1}')
    #echo "speaker " $speaker
    for inputfile in *; do
      get_exif_metadata
      # Check if the file extension is in the list of known audio formats
      if [[ ! " ${audio_formats[@]} " =~ " ${file_type_extension} " ]]; then
        # If not, shift to the next element in the for loop
        continue
      fi
      # Your processing code goes here
      echo "Processing file: $inputfile"
      mkdir with-intro
      say -v $speaker "$title" -o title.wav --data-format=LEF32@22050
      ffmpeg -i title.wav -vn -ar "$file_sample_rate" -ac 2 -b:a "$file_bit_rate" title."$file_type_extension"
      cp "$inputfile" "$sanitized_filename_with_ext"
      ffmpeg -i "concat:title.${file_type_extension}|${sanitized_filename_with_ext}" -acodec copy './with-intro/'"${file_name}"
      rm $sanitized_filename_with_ext
      rm title.wav
      rm title."$file_type_extension"
      echo "Finsihed processing " $file_name
    done
    ;;
  ${ENV_LINUX})
    for inputfile in *; do
      echo "$inputfile"
      exiftool -json "$inputfile" | jq '.[0].Title' | espeak -vde -w /tmp/title.wav
      ffmpeg -i /tmp/title.wav -i "$inputfile" -filter_complex "[0:a:0][1:a:0]concat=n=2:v=0:a=1[outa]" -map "[outa]" -map_metadata 1 -ab 128k -ac 2 -ar 44100 "${inputfile%.*}.with_intro.${inputfile##*.}"
    done
    ;;
esac

exit 1
