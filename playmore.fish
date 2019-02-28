#!/usr/bin/fish

# Right, there should be a definition of the folder to save the music, in the meantime:
set SAVE_HERE $HOME/Music


function findsong
  lynx --dump "https://tunebat.com/Search?q=$argv" | grep " 6. https" | cut -d" " -f5
end


function getmetadata
  set song (findsong $argv)
  lynx --dump $song | grep Info | cut -f3 -d" " | grep Info
end


function getsongurl
  lynx --dump "https://www.youtube.com/results?search_query=$argv" | grep watch | head -1 | cut -d" " -f4
end


function getsongdata
  set artist (pup -f /tmp/songdata 'h2.main-artist-name text{}')
  set track (pup -f /tmp/songdata 'h1.main-track-name text{}')
  set album (pup -f /tmp/songdata 'tr:nth-child(2) > td.main-detail-value text{}')
  echo -e $artist"\n"$track"\n"$album
end


function getalbumimage
  set image (pup -f /tmp/songdata "img.album-cover json{}" | jq .[].src | sed 's/"//g')
  curl -o /tmp/coverimage $image 2>/dev/null
  convert /tmp/coverimage /tmp/readyimage.png
end


function addtags
  mp4tags $SAVE_HERE/$argv[4] -a $argv[1] -s $argv[2] -A $argv[3] -P /tmp/readyimage.png -R $argv[1]
end


function playmore
  set searchterm (echo "cancel" | dmenu -p "Type artist and song")
  switch $searchterm
    case cancel
      return
    case '*'
      echo "Searching for: $searchterm"
  end
  set first true
  mpc clear -q
  set metadata (getmetadata $searchterm)
  for song in $metadata
    curl -s $song > /tmp/songdata 2>/dev/null
    set songdata (getsongdata)
    set forurl (echo $songdata[1] $songdata[2])
    set dirtyfile (echo $songdata[2]-$songdata[1].m4a)
    # This is here because Mopidy's Python is not happy with the filenames, Bash&Fish couldn't care less
    set forfile (echo $dirtyfile | sed 's/ //1' | sed 's/ \././g' | recode html/.. | iconv -f utf-8  -t ascii//translit )
    if test -e $SAVE_HERE/$forfile
      echo $forfile exists
      mpc insert file://$SAVE_HERE/$forfile
    else
      echo getting $forfile
      getalbumimage
      youtube-dl -f 140 (getsongurl $forurl) -o $SAVE_HERE/$forfile && \
      addtags $songdata $forfile && \
      mpc insert file://$SAVE_HERE/$forfile
    end
    # No need to wait for the others to download to start playing
    if test $first = true
      mpc play -q
      set first false
    end
  end
end

playmore
