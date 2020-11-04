# build a new image with centos-jdk-ssh
FROM centos:latest
LABEL tchandrap <tchandrap@gmail>


ARG JAVA_CANDIDATE=java
ARG JAVA_CANDIDATE_VERSION=8.0.272.j9-adpt
ARG MAVEN_CANDIDATE=maven
ARG MAVEN_CANDIDATE_VERSION=3.6.3

ENV SDKMAN_DIR=/root/.sdkman

# update the image
RUN yum -y upgrade


# install requirements, install and configure sdkman
# see https://sdkman.io/usage for configuration options
RUN yum -y install curl ca-certificates zip unzip openssl which findutils git && \
    update-ca-trust && \
    curl -s "https://get.sdkman.io" | bash && \
    echo "sdkman_auto_answer=true" > $SDKMAN_DIR/etc/config && \
    echo "sdkman_auto_selfupdate=false" >> $SDKMAN_DIR/etc/config

# Source sdkman to make the sdk command available and install candidate
RUN bash -c "source $SDKMAN_DIR/bin/sdkman-init.sh && sdk install $JAVA_CANDIDATE $JAVA_CANDIDATE_VERSION && sdk install $MAVEN_CANDIDATE $MAVEN_CANDIDATE_VERSION"

# Add candidate path to $PATH environment variable
ENV JAVA_HOME="$SDKMAN_DIR/candidates/java/current"
ENV PATH="$JAVA_HOME/bin:$PATH"
ENV MAVEN_HOME="$SDKMAN_DIR/candidates/maven/current"
ENV PATH="$MAVEN_HOME/bin:$PATH"

# install openssh
RUN yum -y  install openssh-server openssh-clients
RUN yum install -y https://github.com/OpenNebula/addon-context-linux/releases/download/v4.14.3/one-context_4.14.3.rpm

RUN sed -ri 's/^#PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -ri 's/^UsePAM yes/UsePAM no/' /etc/ssh/sshd_config
RUN sed -i 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' /etc/pam.d/sshd

ENV NOTVISIBLE="in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile

#generate key files
RUN ssh-keygen -q -t rsa   -b 2048 -f /etc/ssh/ssh_host_rsa_key      -N ''
RUN ssh-keygen -q -t ecdsa         -f /etc/ssh/ssh_host_ecdsa_key    -N ''
RUN ssh-keygen -q -t dsa           -f /etc/ssh/ssh_host_ed25519_key  -N ''

# login localhost without password
RUN ssh-keygen -f /root/.ssh/id_rsa -N ''
RUN touch /root/.ssh/authorized_keys
RUN cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys

#get and build dbeam
RUN cd /opt && git clone https://github.com/spotify/dbeam && cd dbeam && mvn clean package -Ppack

ENV WORKING_DIR="/opt/dbeam"

# set password of root
RUN echo "root:admin" | chpasswd 

RUN sed -i 's/#*PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config

# SSH login fix. Otherwise user is kicked off after login
RUN sed -i 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' /etc/pam.d/sshd

ENV NOTVISIBLE="in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile

EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]