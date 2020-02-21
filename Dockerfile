# Build with: docker build -t yubiset_arch .
# Run with: docker run -it yubiset_arch /bin/bash
# Remove Container(s) on Windows: for /F "tokens=*" %i in ('docker ps -aqf "ancestor=yubiset_arch"') do docker rm -f %i
# Remove Container(s) on Unix: docker rm -f $(docker ps -aqf "ancestor=yubiset_arch")
# Remove with: docker image rm -f yubiset_arch

FROM archlinux:latest

RUN groupadd -r usergroup && useradd --no-log-init -r -g usergroup user
RUN mkdir /home/user
ADD yubiset /home/user/yubiset
RUN find /home/user/yubiset -exec chown user:usergroup {} \;
#rw-r--r--
RUN find /home/user/yubiset -type f -iname "*" -exec chmod 0644 {} \;
#rwx-r--r--
RUN find /home/user/yubiset -type f -iname "*.sh" -exec chmod 740 {} \;
USER user
WORKDIR /home/user/yubiset
