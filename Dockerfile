# vim: set expandtab tabstop=2 shiftwidth=2 softtabstop=2:
FROM quay.io/goodguide/base:ubuntu-15.10-0

ENV PREFIX /usr/local

# Set up PPAs
RUN add-apt-repository ppa:git-core/ppa \

 # Install base packages
 && apt-get update \
 && apt-get install \
      ack-grep \
      apt-transport-https \
      build-essential \
      bzr \
      curl \
      exuberant-ctags \
      git \
      htop \
      less \
      man-db \
      manpages \
      mercurial \
      mosh \
      net-tools \
      ssh-client \
      subversion \
      wget \
      zsh

# Set up ssh server
EXPOSE 22
RUN apt-get install \
      openssh-server \

 # Delete the host keys it just generated. At runtime, we'll regenerate those
 && rm -f /etc/ssh/ssh_host_* \

 && mkdir -pv /var/run/sshd /root/.ssh \
 && chmod 0700 /root/.ssh

# Install Golang
ENV GOROOT=$PREFIX/go GOPATH=/root/gopath
ENV PATH $GOROOT/bin:$PATH
RUN set -x \
 && cd /tmp \
 && curl -fsSL -o go.tgz https://storage.googleapis.com/golang/go1.5.1.linux-amd64.tar.gz \
 && shasum go.tgz | grep -q 46eecd290d8803887dec718c691cc243f2175fe0 \
 && mkdir -vp "$GOROOT" \
 && tar -xvz -C "$GOROOT" --strip-components=1 -f go.tgz \
 && rm -v /tmp/go.tgz

RUN echo "export GOROOT=$GOROOT" >> /root/.profile \
 && echo "export GOPATH=$GOPATH" >> /root/.profile \
 && echo "export PATH=$GOPATH/bin:$GOROOT/bin:\$PATH" >> /root/.profile \
 && mkdir -p $GOPATH

# Install VIM
RUN set -x \
 && apt-get install \
      libacl1 \
      libc6 \
      libgpm2 \
      libncurses5-dev \
      libselinux1 \
      libssl-dev \
      libtcl8.6 \
      libtinfo5 \
      python-dev \

 && git clone https://github.com/vim/vim.git /opt/vim \
 && cd /opt/vim \
 && git checkout v7.4.922 \
 && ./configure --with-features=huge --with-compiledby='docker@goodguide.com' \
 && make \
 && make install

# Install tmux
RUN set -x \
 && apt-get install \
      automake \
      libevent-dev \
      pkg-config \
 && git clone https://github.com/tmux/tmux.git /opt/tmux \
 && cd /opt/tmux \
 && git checkout 2.1 \
 && ./autogen.sh \
 && ./configure \
 && make \
 && make install

# Install Docker-client
RUN set -x \
 && apt-key adv --keyserver 'hkp://p80.pool.sks-keyservers.net:80' --recv-keys '58118E89F3A912897C070ADBF76221572C52609D' \
 && echo 'deb https://apt.dockerproject.org/repo ubuntu-wily main' > /etc/apt/sources.list.d/docker.list \
 && apt-get update \
 && apt-get install docker-engine

# Install docker-compose
RUN set -x \
 && curl -fsSL -o /tmp/docker-compose "https://github.com/docker/compose/releases/download/1.5.2/docker-compose-`uname -s`-`uname -m`" \
 && shasum -a 256 /tmp/docker-compose | grep -q 'b6b975badc5389647ef1c16fe8a33bdc5935c61f6afd5a15a28ff765427d01e3' \
 && install -v /tmp/docker-compose "$PREFIX/bin/docker-compose" \
 && rm -vrf /tmp/*

# Install direnv
RUN set -x \
 && curl -fsSL -o /tmp/direnv https://github.com/zimbatm/direnv/releases/download/v2.6.0/direnv.linux-amd64 \
 && shasum /tmp/direnv | grep -q 'ccc0b6569c39951d22ce7379b15fdffddb62d82d' \
 && install -v /tmp/direnv $PREFIX/bin/direnv \
 && rm -vrf /tmp/*

# install goodguide-git-hooks
RUN go get -u -v github.com/goodguide/goodguide-git-hooks

# install forego
RUN go get -u -v github.com/ddollar/forego

RUN go get -v github.com/github/hub

# install jq 1.5
COPY docker_runtime/gpg/jq_signing.key.pub.asc /tmp/
RUN set -x \
 && curl -fsSL -o /tmp/jq https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 \
 && curl -fsSL -o /tmp/jq.sig.asc https://raw.githubusercontent.com/stedolan/jq/master/sig/v1.5/jq-linux64.asc \
 && gpg --import /tmp/jq_signing.key.pub.asc \
 && gpg --verify /tmp/jq.sig.asc /tmp/jq \
 && install -v /tmp/jq $PREFIX/bin/jq \
 && rm -vfv /tmp/*

# install AWS CLI
RUN set -x \
 && apt-get install python-pip \
 && pip install awscli \
 && rm -vrf /tmp/*

# install latest release of thoughtbot's `pick` tool
RUN set -x \
 && version=1.2.1 \
 && curl -fsSL -o /tmp/pick.tar.gz.sig.asc "https://github.com/thoughtbot/pick/releases/download/v${version}/pick-${version}.tar.gz.asc" \
 && curl -fsSL -o /tmp/pick.tar.gz "https://github.com/thoughtbot/pick/releases/download/v${version}/pick-${version}.tar.gz" \
 && gpg --recv-keys 35689C84 \
 && gpg --verify /tmp/pick.tar.gz.sig.asc /tmp/pick.tar.gz \
 && tar -xvz -C /tmp -f /tmp/pick.tar.gz \
 && cd /tmp/pick-${version} \
 && ./configure \
 && make \
 && make install \
 && rm -vrf /tmp/*

# Set up some environment for SSH clients (ENV statements have no affect on ssh clients)
RUN echo "export DOCKER_HOST='unix:///var/run/docker.sock'" >> /root/.profile
RUN echo "export DEBIAN_FRONTEND=noninteractive" >> /root/.profile

# Set shell to zsh
RUN usermod -s /usr/bin/zsh root

COPY docker_runtime/entrypoint.sh /usr/local/bin/start_sshd
COPY etc/ssh/* /etc/ssh/
COPY etc/pam.d/* /etc/pam.d/

# use a volume for the SSH host keys, to allow a persistent host ID across container restarts
VOLUME ["/etc/ssh/ssh_host_keys"]
ENTRYPOINT ["/usr/local/bin/start_sshd"]

# these volumes allow creating a new container with these directories persisted, using --volumes-from
VOLUME ["/code", "/root"]

WORKDIR /root
