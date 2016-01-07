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

