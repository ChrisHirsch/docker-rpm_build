FROM centos:6
MAINTAINER Chris Hirsch <chris@base2technology.com>
ENV REFRESHED_AT 2015-02-19
ENV DOCKER 1
ENV JAVA_HOME /usr/java/default

# Bring in any needed repos
RUN rpm -Uvh https://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm

# Update to latest
RUN yum update -y

# Bring in needed packages
RUN yum -y install rpm-build make gcc tar rsync httpd-devel curl-devel libstdc++-devel

COPY make-env /make-env 

WORKDIR /src

ENTRYPOINT ["make"]

CMD ["pkg"]

