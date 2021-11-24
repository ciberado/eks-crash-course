FROM byrnedo/alpine-curl

ENTRYPOINT ["sh", "-c", "sleep $(($RANDOM % 10)); name=$(curl 'http://names.drycodes.com/1?format=text'); let i=0 ; while :; do let i++; printf \"%s %-20s %-4s\n\" $HOSTNAME $name $i;  sleep 5; done"]
