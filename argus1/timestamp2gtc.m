function gtc = timestamp2gtc(timestamp)

hrs = floor(timestamp/10000);
mns = floor(rem(timestamp,10000)/100);
scs = rem(timestamp,100);

gtc = 60*60*hrs + 60*mns + scs;