FROM golang:1.7.3-wheezy

################################################################################
#                                  RabbitMQ                                    #
################################################################################
RUN apt-get update; \
    apt-get install -y apt-transport-https
RUN echo 'deb http://www.rabbitmq.com/debian/ testing main' | tee /etc/apt/sources.list.d/rabbitmq.list && \
    wget -O- https://www.rabbitmq.com/rabbitmq-release-signing-key.asc | apt-key add - && \
    gpg --keyserver pgpkeys.mit.edu --recv-key 7638D0442B90D010 && \
    gpg -a --export 7638D0442B90D010 | apt-key add - && \
    echo 'deb http://ftp.debian.org/debian wheezy-backports main' | tee /etc/apt/sources.list.d/wheezy_backports.list && \
    wget -O- https://packages.erlang-solutions.com/debian/erlang_solutions.asc | apt-key add - && \
    echo 'deb https://packages.erlang-solutions.com/debian wheezy contrib' | tee /etc/apt/sources.list.d/esl.list
RUN apt-get update; \
    apt-get install -y init-system-helpers socat esl-erlang

RUN wget -O- https://www.rabbitmq.com/rabbitmq-release-signing-key.asc | apt-key add - && \
    echo 'deb http://www.rabbitmq.com/debian/ testing main' | tee /etc/apt/sources.list.d/rabbitmq.list
RUN apt-get update && \
    apt-get install -y rabbitmq-server zlib1g-dev libssl-dev nmap 

ADD https://bootstrap.pypa.io/get-pip.py /tmp/get-pip.py

RUN python /tmp/get-pip.py

ADD https://www.python.org/ftp/python/2.7.12/Python-2.7.12.tgz /tmp/Python-2.7.12.tgz
RUN tar xfz /tmp/Python-2.7.12.tgz
RUN cd Python-2.7.12/ && \
    ./configure --prefix /usr/local/lib/python2.7.12 --enable-ipv6  --enable-unicode=ucs4 && \
        make && \
        make install && \
    cd ..

RUN rm -r Python-2.7.12*

RUN pip install --upgrade virtualenv
RUN virtualenv  --python=/usr/local/lib/python2.7.12/bin/python venv

RUN /go/venv/bin/pip install pyvmomi python-nmap

################################################################################
#                                 Terraform                                    #
################################################################################
ADD terraform /usr/bin/terraform


################################################################################
#                                  Go Deps                                     #
################################################################################
RUN go get github.com/onsi/ginkgo/ginkgo && \
    go get github.com/onsi/gomega && \
    go get github.com/streadway/amqp
