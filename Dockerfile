FROM ubuntu:16.04
MAINTAINER Kyro <kyro@koddi.com>

# packages
RUN apt-get update && apt-get install -yq --no-install-recommends --force-yes \
    tar \
    wget \
    git \
    openjdk-8-jdk \
    autoconf \
    libtool \
    build-essential \
    python-dev \
    libcurl4-nss-dev \
    maven \
    libapr1-dev \
    libsvn-dev \
    zlib1g-dev \
    libsasl2-dev \
    libsasl2-modules && \
    rm -rf /var/lib/apt/lists/*

    #apt-transport-https && \
# Overall ENV vars
ENV SBT_VERSION 0.14.3
ENV SCALA_VERSION 2.11.8
ENV SPARK_VERSION 2.0.1
ENV MESOS_BUILD_VERSION 1.1.0
ENV SPARK_JOBSERVER_BRANCH spark-2.0-preview
#ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk

# SBT install
RUN echo "deb http://dl.bintray.com/sbt/debian /" | tee -a /etc/apt/sources.list.d/sbt.list && \
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 2EE0EA64E40A89B84B2DF73499E82A75642AC823 && \
    apt-get update && \
    apt-get install sbt

# Scala install
RUN wget http://downloads.typesafe.com/scala/$SCALA_VERSION/scala-$SCALA_VERSION.deb && \
    dpkg -i scala-$SCALA_VERSION.deb && \
    rm scala-$SCALA_VERSION.deb

# Mesos install
RUN wget http://archive.apache.org/dist/mesos/$MESOS_BUILD_VERSION/mesos-$MESOS_BUILD_VERSION.tar.gz
RUN mkdir -p /usr/local/mesos && \
    tar -zxf  mesos-$MESOS_BUILD_VERSION.tar.gz && \
    mv mesos-$MESOS_BUILD_VERSION/* /usr/local/mesos/ && \
    rm mesos-$MESOS_BUILD_VERSION.tar.gz && \
    cd /usr/local/mesos/ && \
    mkdir build && \
    cd build && \
    ../configure && \
    make  && \
    make install

# Spark ENV vars
ENV SPARK_VERSION_STRING spark-$SPARK_VERSION-bin-hadoop2.7
ENV SPARK_DOWNLOAD_URL http://d3kbcqa49mib13.cloudfront.net/$SPARK_VERSION_STRING.tgz

# Download and unzip Spark
RUN wget $SPARK_DOWNLOAD_URL && \
    mkdir -p /usr/local/spark && \
    tar xvf $SPARK_VERSION_STRING.tgz -C /tmp && \
    cp -rf /tmp/$SPARK_VERSION_STRING/* /usr/local/spark/ && \
    rm -rf -- /tmp/$SPARK_VERSION_STRING && \
    rm spark-$SPARK_VERSION-bin-hadoop2.7.tgz

# Set SPARK_HOME
ENV SPARK_HOME /usr/local/spark

# Set native Mesos library path
ENV MESOS_NATIVE_JAVA_LIBRARY /usr/local/lib/libmesos.so

# H2 Database folder for Spark JobServer
RUN mkdir -p /database

# Clone Spark-Jobserver repository
ENV SPARK_JOBSERVER_BUILD_HOME /spark-jobserver
ENV SPARK_JOBSERVER_APP_HOME /app
RUN git clone --branch $SPARK_JOBSERVER_BRANCH https://github.com/spark-jobserver/spark-jobserver.git
RUN mkdir -p $SPARK_JOBSERVER_APP_HOME

# Add custom files, set permissions
ADD docker.conf $SPARK_JOBSERVER_BUILD_HOME/config/docker.conf
ADD docker.sh $SPARK_JOBSERVER_BUILD_HOME/config/docker.sh
ADD log4j-docker.properties $SPARK_JOBSERVER_BUILD_HOME/config/log4j-server.properties
ADD server_deploy.sh $SPARK_JOBSERVER_BUILD_HOME/bin/server_deploy.sh
RUN chmod +x $SPARK_JOBSERVER_BUILD_HOME/bin/server_deploy.sh
RUN chmod +x $SPARK_JOBSERVER_BUILD_HOME/bin/server_start.sh
RUN chmod +x $SPARK_JOBSERVER_BUILD_HOME/bin/server_stop.sh

# Build Spark-Jobserver
WORKDIR $SPARK_JOBSERVER_BUILD_HOME
RUN bin/server_deploy.sh docker && \
    cd / && \
    rm -rf -- $SPARK_JOBSERVER_BUILD_HOME

# Cleanup files, folders and variables
RUN unset SPARK_VERSION_STRING && \
    unset SPARK_DOWNLOAD_URL && \
    unset SPARK_JOBSERVER_BRANCH && \
    unset SPARK_JOBSERVER_BUILD_HOME && \
    unset MESOS_BUILD_VERSION

#EXPOSE 8090 9999

ENTRYPOINT ["/app/server_start.sh"]
