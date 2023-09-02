FROM debian:buster

RUN apt-get update -y
RUN apt-get install -y ssh sudo

RUN apt-get -y install openssh-server
# RUN useradd -m vagrant
# RUN echo "password\npassword" | passwd vagrant
RUN useradd -m vagrant && echo "password\npassword" | passwd vagrant && adduser vagrant sudo

USER vagrant
RUN mkdir -p ~/.ssh

EXPOSE 22

COPY "./confs/id_rsa.pub" "/home/vagrant/.ssh"
COPY "./scripts/server_setup.sh" "."

RUN curl -sfL https://get.k3s.io | sh -
# RUN chmod 777 server_setup.sh

CMD ["tail", "-f", "/dev/null"]