mkfifo onerandom tworandom
tee onerandom tworandom < /dev/urandom > /dev/null &
shuf --random-source=onerandom bitext.en > onefile.shuf &
shuf --random-source=tworandom bitext.de > twofile.shuf &
wait

