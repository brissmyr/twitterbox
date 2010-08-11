#!/bin/sh

# Run script with: /etc/twitter/curl -s -N -d @/etc/twitter/tracking http://stream.twitter.com/1/statuses/filter.xml -uSSWCHolken:futureinstereo | /etc/twitter/tweet.sh

PASSWD=gyllen

if [ "$1" = "local" ]; then
    PREFIX=.
    HAS_RANDOM=y
    HOST=$2
else
    PREFIX=/etc/twitter
    HAS_RANDOM=n
    HOST=localhost
fi

get_quote() {
    screen_name="@$1"
#    RANGE=$(wc -l $PREFIX/messages.txt | sed -n -e 's/[ ]*\(.*\) m.*/\1/p')
    RANGE=$(wc -l $PREFIX/messages.txt  | sed -n -e 's/[ ]*\(.*\) .*/\1/p')

    if [ "$HAS_RANDOM" = "y" ]; then
        number=$RANDOM
    else
        # TODO: Rewrite with builtins
        number=$(cat /proc/interrupts | sed '2q;d' | sed 's/.*[0-9]*:[ ]* \(.*\) C.*/\1/')
    fi
    number=$(expr $number % $RANGE)
    number=$(($number + 1))

    echo $(eval sed -n '${number}p' $PREFIX/messages.txt) | eval sed -e 's/SCREEN_NAME/$screen_name/'
}

screen_name=""
text=""
tweet=""
logger "Listening for tweets"
while [ 1 ]; do
        read tmp
        if [ "$tmp" = "" ]; then
            continue
        fi

        # This handles </status> surrounded by spaces
        t="${tmp##*</status}"
        if [ "${t##>*}" != "" ]; then
            tweet="${tweet}${tmp}"
        else
            screen_name=$(echo $tweet | sed -n -e 's/.*<screen_name>\(.*\)<\/screen_name>.*/\1/p')
            echo "$screen_name triggered a capture"
            $PREFIX/curl -s -o $PREFIX/image.jpg http://root:$PASSWD@$HOST/jpg/image.jpg?compression=10
            $PREFIX/curl -s http://root:$PASSWD@$HOST/axis-cgi/playclip.cgi?clip=9
            echo "Got image!"
            quote="$(get_quote $screen_name)"
            echo $quote

            MAX_FAILS=3
            FAILS=0
            while [ $FAILS -lt $MAX_FAILS ]; do
                $PREFIX/curl -s -oreply -F message="$quote #xxwc" -F username=SSWCHolken -F password=futureinstereo -F media=@$PREFIX/image.jpg http://yfrog.com/api/uploadAndPost
                REPLY=$(cat reply)
                REPLY=${REPLY#*fail}
                REPLY=${REPLY%%\">*}
                if [ "$REPLY" = "" ]; then
                    FAILS=$(($FAILS + 1))
                    if [ $FAILS -eq $MAX_FAILS ]; then
                        echo "TODO: send a tweet to @brissmyr"
                    else
                        echo "FAIL! Could not upload photo. Retrying..."
                    fi
                else
                    echo "Photo uploaded!"
                    FAILS=$MAX_FAILS
                fi
            done
        fi
done
