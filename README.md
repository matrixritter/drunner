# dRunner

The aim of dRunner is to easen the usage of docker for small to medium web development projects. From my perception, docker hasn't seen widespread adoption in a field, where it's not about coding the next big thing than making this @&#% wordpress plugin working.

To make this possible, dRunner reads from a dotfile in your project folder and starts a docker container with predefined port forwardings and mounted folders.

## Disclaimer 

dRunner is written in Perl 5 and works currently just under Mac OSX. I'm still working my way through the advanced chapters of the brilliant book [Beginning Perl](http://www.wrox.com/WileyCDA/WroxTitle/productCd-1118013840.html). A rewrite with Moose will happen at any point in the future. 

I take no resposibility if my script wipes your disk or kills a kitten.

## Prerequisites

You need a local docker host provided by [Docker Machine](https://www.docker.com/docker-machine) with Virtualbox.

## Installation

I strongly advise to use [Perlbrew](http://perlbrew.pl/) and leave your system provided Perl environment as-is.

```bash
perlbrew install perl-5.22.1
perlbrew use perl-5.22.1
cpanm Git
cpanm Config::Tiny
cpanm forks
cpanm File::Find::Rule
cpanm --force LWP::Protocol::https
cpanm Eixo::Docker
git clone https://github.com/matrixritter/drunner.git
```

Either you run the `drun.pl` directly or add a shell alias.

## Usage

Drop a `.drunner.ini` in your project folder, change to this folder in your shell and execute `drun.pl`. Currently the following commands are usable:

```bash
./drun.pl <command>
status                      # checks if a configuration file is found and a docker host is available in your $environment
start                   # starts a docker container and sets up port forwardings
stop                        # stops the container and removes the forwardings
```

### Configuration file

The configuration file is in the ini format. I find it quite readable and easy to work with (even the limitations). The file consists of a head part and sections which will be read if referred to:

```ini
repository=<repository of your docker container>
tag=<version of your docker container>
root_directory=<empty, for future use>
services=<comma-seperated list>
databases=<comma-seperated list>
mounts=<comma-seperated list>
```

There has to be a section for every list item.

#### databases

This type has the following syntax:

```ini
[<name>]
container_port=<listening port of your database server inside the container>
description=<empty, for future use>
fqdn=<empty, for future use>
name=<database name>
type=[tcp|udp]
```

#### mounts

This type has the following syntax:

```ini
[<name>]
container_mount=<mountpoint inside the container>
host_directory=<directory name relativ to the .drunner.ini>
mounted=<empty, filled by drun.pl>
```

#### services

This type has the following syntax:

```ini
[http]
container_port=<listening port of the service inside the container>
description=<empty, for future use>
fqdn=<empty, for future use>
name=<name of the service>
type=[tcp|udp]
```
