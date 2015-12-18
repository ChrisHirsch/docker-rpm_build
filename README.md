# RPM Build environment
=====

A simple concise RPM build environment that lets you build and package RPMS on Linux/OSX/Windows etc. 

With this build environment, you can dynamically generate RPM spec files, build those spec files and never have to look back.

Currently this project uses CentOS 6 and rpmbuild. If a later version is needed, simply update the Dockerfile and rebuild. There is also a CentOS 7 branch (centos_7) that can be used to build CentOS 7 packages.

# Make an RPM

This project is a Docker container for [rpmbuild](http://rpm.org/). It's a simple environment that contains a simple script to allow a user to build rpms in a portable way.

## Getting/Building the container

	$ git clone git@github.com:ChrisHirsch/docker-rpm_build.git
	$ cd rpm_build
	$ make

## Using the container

The idea is that as a packager, you just want to package the source in a nice portable way. This is easily accomplished with the command:

	$ make pkg

The pkg target (see below on Setting up your Makefile) will run the rpm_build Docker container, expose your local source $(pwd) to the Docker container as /src. Then re-run the makefile in $(pwd) and the pkg target which will now execute a different pkg target because the DOCKER env variable is defined. If the Makefile is correctly set up, an RPM will be produced in the $(pwd)/pkg directory.

## Setting up your Makefile
At a minimum you will need to have have a the variables and targets as shown below:
```
PROJECT = <desired name>
OS_ARCH = noarch
VOLUMES=-v $$(pwd):/src

pkg:
	docker run --rm --tty --interactive $(VOLUMES) chrishirsch/rpm_build
```

Set PROJECT to be the desired rpm name ie if tla-myproject then you will get something like tla-myproject-1.0.0.rpm
If the architecture is not compiled and is a noarch project then set OS_ARCH = noarch. Otherwise don't set this.
You can expose the source code by another directory with VOLUMES but it must be AT /src

The rest is just hardcoded template ie you MUST have the pkg defined like shown.

## How does this work?
The make-env make.rules in the container contains a little black magic where if the DOCKER env variable is defined we redefine our pkg target
```
ifdef DOCKER
pkg: buildloop
else
pkg:
	docker run --rm --tty --interactive $(VOLUMES) chrishirsch/rpm_build
endif
# Include our make rules if and only if we are buidling from within docker
ifdef DOCKER
include env/make.rules
endif
``` 

## Specfile options

### To filter out auto-computed pre-reqs
Add the maching grep -v syntax to NOT look at for the provides or requires

FILTER_PROVIDES = .so
FILTER_REQUIRES = .so

By adding .so, the grep that determines which files to look at to run provides/requires will be run to INVERT the match. 
So if FILTER_PROVIDES = badlib.so then goodlib.so would be looked at for PROVIDES but badlib.so would NOT

#### Filtering a directory so RPM will not auto-find dependencies
If you wish to not have the build try and be smart (and want to do your own requirements) try something like:
```
FILTER_REQUIRES = $(ROOT)/opt/sw
```

Where in your makefile your copy_files: looks something like
```
copy_files: clean
        mkdir -p $(ROOT)/opt/sw
        rsync -av version.txt --exclude=Dockerfile --exclude=env/ --exclude '.hg' --exclude=pkg/ --exclude=install/ --exclude=Makefile . $(ROOT)/opt/sw
```
and will copy all your perl, python, whatever into that /opt/sw directory

### To set the architecture (in the case of noarch)
If the desired package architecture is noarch or something besides the autodetected simply set 

OS_ARCH = noarch

in your Makefile
By adding noarch, the RPM package that will be produced will be architecture independent. More information about arch RPMs can be 
found [here](https://unix.stackexchange.com/questions/204800/when-to-use-arch-vs-noarch-when-building-rpms)

### To make a file a config file (ie don't overwrite it on update)
Create an env/spec.config file that has the fully qualified path of the config like
```
/etc/myproject/myconfig.xml
```
This will create a %config(noreplace) option for each file listed in the spec.config

Why %config(noreplace)? look [here](http://www-uxsup.csx.cam.ac.uk/~jw35/docs/rpm_config.html) for details.

Thanks
------
A HUGE thanks to Glenn Zazulia, James Whiteacre, Duane (Griz) Bates, Dan Babb and many others I'm sure I've forgotten for making this project possible. Standing on the shoulders of giants here.
