#!/bin/bash
shopt -s extglob

# Define supported audio formats
audio_formats=("mp3" "mp4" "wav" "flac" "aac" "ogg" "m4a")

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
  if [[ "${file_sample_rate}" == "null" ]]; then
    file_sample_rate=$(echo "$metadata" | jq -r '.[0].AudioSampleRate')
  fi
  if [[ "${file_sample_rate}" == "null" ]]; then
    print_error "Could not determine sample rate for ${inputfile}"
    exit 1
  fi
  
  file_bitrate=$(echo "$metadata" | jq -r '.[0].AudioBitrate')
  if [[ "${file_bitrate}" == "null" ]]; then
    file_bitrate=$(echo "$metadata" | jq -r '.[0].AvgBitrate')
  fi
  if [[ "${file_bitrate}" == "null" ]]; then
    print_error "Could not determine bit rate for ${inputfile}"
    exit 1
  fi
  file_kbit_rate=$(echo "$file_bitrate" | awk 'NR==1{print $1}')
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

for inputfile in *; do
  get_exif_metadata

  if [[ ! " ${audio_formats[@]} " =~ " ${file_type_extension} " ]]; then
    echo "Skipping file: $inputfile" 
    continue
  fi

  echo "Processing file: $inputfile"

  case $env in
    ${ENV_OSX})
      title_wav="title.wav"
      speaker=$(say -v \? | grep "$locale" | awk 'NR==1{print $1}')
      say -v $speaker "$title" -o "${title_wav}" --data-format=LEF32@22050
      mkdir -p with-intro
      output_file="./with-intro/${file_name}"
      ;;
    ${ENV_LINUX})
      title_wav="/tmp/title.wav"
      tts --model_name tts_models/de/thorsten/tacotron2-DDC --out_path "${title_wav}" --text "$title"
      output_file="${inputfile%.*}.with_intro.${inputfile##*.}"
      ;;
  esac
  
  title_converted=title."$file_type_extension"
  ffmpeg -i "${title_wav}" -vn -ar "$file_sample_rate" -ac 2 -b:a "$file_bit_rate" "${title_converted}"
  cp "$inputfile" "$sanitized_filename_with_ext"
  # Using the ffmpeg's Concat protocol as follows would be more elegant but does not work e.g. for formats with metadata elements, like .m4a:
  #   ffmpeg -i "concat:${title_converted}|${sanitized_filename_with_ext}" -acodec copy "${output_file}"
  ffmpeg -f concat -safe 0 -i <(echo "file '$PWD/${title_converted}'"; echo "file '$PWD/${sanitized_filename_with_ext}'") -acodec copy "${output_file}"
  rm "${title_wav}" "${title_converted}" "$sanitized_filename_with_ext"

  echo "Finished processing $inputfile"

done

exit 0
