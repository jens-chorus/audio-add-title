#!/bin/sh

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
      exit 1
      ;;
  esac
}

check_dependencies_list()
{
  dependencies=$1
  
  set -- ${dependencies}
  while [ -n "$1" ]; do
    dependency=$1
    command -v ${dependency} >/dev/null 2>&1 || {
      print_error "${dependency} needs to be installed."
      echo 1
    }
    shift
  done
}

check_dependencies()
{
  env=$1
  echo "Checking dependencies... "
  
  common_dependencies="jq ffmpeg exiftool"
  deps_are_missing=$(check_dependencies_list "${common_dependencies}")
  
  case $env in
    ${ENV_OSX})
      echo "OSX"
      ;;
    ${ENV_LINUX})
      linux_dependencies="espeak"
      deps_are_missing="${deps_are_missing}$(check_dependencies_list "${linux_dependencies}")"
      ;;
  esac
  
  if [ -n "${deps_are_missing}" ]
  then {
    print_error "Install the above and rerun this script"
    exit 1
  }
  else
    echo "\tOK"
  fi
}


env="$(detect_environment)"
check_dependencies "${env}"

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
    echo "speaker " $speaker
    for inputfile in *; do
      echo "$inputfile"
      title=$(exiftool -json "$inputfile" | jq -r '.[0].Title') && echo $title && say -v $speaker "$title" -o title.wav --data-format=LEF32@22050
      ffmpeg -i title.wav -i "$inputfile" -filter_complex "[0:a:0][1:a:0]concat=n=2:v=0:a=1[outa]" -map "[outa]" -map_metadata 1 -ab 128k -ac 2 -ar 44100 "./with-intro/${inputfile%.*}-$title.with_intro.${inputfile##*.}"
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
