FROM ubuntu:20.04
# FROM ubuntu:latest

ENV TZ=Europe/Kiev
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone


COPY . /source/
WORKDIR /source/

RUN chmod +x /source/install.sh
RUN /source/install.sh
RUN npm i


CMD [ "/bin/sh", "-c", "systemctl start nginx && node /source/bundle/index.js" ]
