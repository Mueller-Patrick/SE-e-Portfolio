#!/bin/sh
mkdir jenkins-master
mkdir jenkins-slave

cd jenkins-master
cat > ./dockerfile << ENDOFFILE
# Starting off with the Jenkins base Image
FROM jenkins/jenkins:latest
# Installing the plugins we need using the in-built install-plugins.sh script
RUN /usr/local/bin/install-plugins.sh git matrix-auth workflow-aggregator docker-workflow blueocean credentials-binding
# Setting up environment variables for Jenkins admin user
ENV JENKINS_USER admin
ENV JENKINS_PASS admin
# Skip the initial setup wizard
ENV JAVA_OPTS -Djenkins.install.runSetupWizard=false
# Start-up scripts to set number of executors and creating the admin user
COPY executors.groovy /usr/share/jenkins/ref/init.groovy.d/
COPY default-user.groovy /usr/share/jenkins/ref/init.groovy.d/
VOLUME /var/jenkins_home
ENDOFFILE
wget https://raw.githubusercontent.com/Mueller-Patrick/SE-e-Portfolio/master/Code_Interconnection/res/master/default-user.groovy
wget https://raw.githubusercontent.com/Mueller-Patrick/SE-e-Portfolio/master/Code_Interconnection/res/master/executors.groovy

cd ..

cd jenkins-slave
cat > ./dockerfile << ENDOFFILE
FROM ubuntu:16.04
# Install Docker CLI in the agent
RUN apt-get update && apt-get install -y apt-transport-https ca-certificates
RUN apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
RUN echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu xenial stable" > /etc/apt/sources.list.d/docker.list
RUN apt-get update && apt-get install -y docker-ce --allow-unauthenticated
RUN apt-get update && apt-get install -y openjdk-8-jre curl python python-pip git
RUN easy_install jenkins-webapi
# Get docker-compose in the agent container
RUN curl -L https://github.com/docker/compose/releases/download/1.21.2/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose
RUN mkdir -p /home/jenkins
RUN mkdir -p /var/lib/jenkins
# Start-up script to attach the slave to the master
ADD slave.py /var/lib/jenkins/slave.py
WORKDIR /home/jenkins
ENV JENKINS_URL "http://jenkins"
ENV JENKINS_SLAVE_ADDRESS ""
ENV JENKINS_USER "admin"
ENV JENKINS_PASS "admin"
ENV SLAVE_NAME ""
ENV SLAVE_SECRET ""
ENV SLAVE_EXECUTORS "1"
ENV SLAVE_LABELS "docker"
ENV SLAVE_WORING_DIR ""
ENV CLEAN_WORKING_DIR "true"
CMD [ "python", "-u", "/var/lib/jenkins/slave.py" ]
ENDOFFILE
wget https://raw.githubusercontent.com/Mueller-Patrick/SE-e-Portfolio/master/Code_Interconnection/res/slave/slave.py

cd ..

cat > ./docker-compose.yml << ENDOFFILE
version: '3.1'
services:
    jenkins:
        build: jenkins-master
        container_name: jenkins
        ports:
            - '8080:8080'
            - '50000:50000'
    jenkins-slave:
        build: jenkins-slave
        container_name: jenkins-slave
        restart: always
        environment:
            - 'JENKINS_URL=http://jenkins:8080'
        volumes:
            - /var/run/docker.sock:/var/run/docker.sock  # Expose the docker daemon in the container
            - /home/jenkins:/home/jenkins # Avoid mysql volume mount issue
        depends_on:
            - jenkins
ENDOFFILE
