#!/bin/bash
shopt -s extglob

# Define supported audio formats
audio_formats=("mp3" "mp4" "wav" "flac" "aac" "ogg")

readonly ENV_OSX='Mac OS X'
readonly ENV_LINUX='Linux'

print_error() {
  echo "$*" >&2
}

detect_environment() {
  case "$(uname -s)" in
    Darwin*) echo "${ENV_OSX}" ;;
    Linux*)  echo "${ENV_LINUX}" ;;
    *)       print_error "Unsupported environment: $(uname -sr)"
             exit 1
             ;;
  esac
}

get_exif_metadata() {
  local metadata
  metadata=$(exiftool -json "$inputfile")
  title=$(echo "$metadata" | jq -r '.[0].Title')
  file_name=$(echo "$metadata" | jq -r '.[0].FileName')
  file_type_extension=$(echo "$metadata" | jq -r '.[0].FileTypeExtension')
  filename_without_ext="${file_name%.*}"
  sanitized_filename_without_ext=$(echo "$filename_without_ext" | iconv -f utf8 -t ascii//TRANSLIT | sed 's/[^a-zA-Z0-9]//g')
  sanitized_filename_with_ext="${sanitized_filename_without_ext}.${file_type_extension}"
  file_sample_rate=$(echo "$metadata" | jq -r '.[0].SampleRate')
  file_kbit_rate=$(echo "$metadata" | jq -r '.[0].AudioBitrate' | awk 'NR==1{print $1}')
  file_bit_rate=$(($file_kbit_rate * 1000))
}

env=$(detect_environment)
locale="de_DE"

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --locale) locale="$2"; shift ;;
    *)        shift ;;
  esac
done

mkdir -p with-intro

case $env in
  ${ENV_OSX})
    speaker=$(say -v \? | grep "$locale" | awk 'NR==1{print $1}')

    for inputfile in *; do
      get_exif_metadata

      if [[ ! " ${audio_formats[@]} " =~ " ${file_type_extension} " ]]; then
        continue
      fi

      echo "Processing file: $inputfile"

      say -v $speaker "$title" -o title.wav --data-format=LEF32@22050
      ffmpeg -i title.wav -vn -ar "$file_sample_rate" -ac 2 -b:a "$file_bit_rate" title."$file_type_extension"
      cp "$inputfile" "$sanitized_filename_with_ext"
      ffmpeg -i "concat:title.${file_type_extension}|${sanitized_filename_with_ext}" -acodec copy "./with-intro/${file_name}"

      rm title.wav title."$file_type_extension" "$sanitized_filename_with_ext"

      echo "Finished processing $file_name"
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

exit 0