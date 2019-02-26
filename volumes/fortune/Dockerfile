FROM ubuntu:latest
RUN apt-get update ; apt-get -y install fortune
ADD fortuneloop.sh /bin/fortuneloop.sh
RUN ["chmod", "777", "/bin/fortuneloop.sh"]
RUN ["chmod", "777", "/usr/games/fortune"]
ENTRYPOINT /bin/fortuneloop.sh
