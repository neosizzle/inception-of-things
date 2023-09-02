FROM debian:buster

RUN apt-get update -y
# RUN apt-get install -y sudo

RUN apt-get -y install openssh-server
# RUN useradd -m vagrant
# RUN echo "password\npassword" | passwd vagrant
RUN useradd -m vagrant && echo "password\npassword" | passwd vagrant

# USER vagrant
RUN mkdir -p ~/.ssh

#
EXPOSE 22

COPY "./confs/id_rsa.pub" "/root/.ssh/authorized_keys"
COPY "./confs/id_rsa.pub" "/root/.ssh/id_rsa.pub"

RUN chmod 700 "/root/.ssh"
RUN chmod 600 "/root/.ssh/authorized_keys"

COPY "./scripts/server_setup.sh" "."
RUN echo "RSAAuthentication yes\nPubkeyAuthentication yes" >> /etc/ssh/sshd_config
RUN mkdir /var/run/sshd
RUN curl -sfL https://get.k3s.io | sh -
# RUN chmod 777 server_setup.sh
CMD ["/usr/sbin/sshd", "-D"]
