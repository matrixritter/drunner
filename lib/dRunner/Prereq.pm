package dRunner::Prereq;

# Boilerplate
use warnings;
use strict;
# use diagnostics;
# use v5.12;
use experimental 'autoderef', 'smartmatch', 'switch'; 
use Data::Dumper;
use autodie;

use Git;
use Config::Tiny;
# use autodie;
use forks;
use Eixo::Docker::Api;
use File::Find::Rule;
use Parse::Netstat qw(parse_netstat);

use Exporter 'import';
our @EXPORT_OK = qw(
	_get_docker_host
    _location_of_configuration_ini
    _initialize_git_repo
    check_and_get_prerequisites
);
# print Dumper(@EXPORT_OK);
our %EXPORT_TAGS = ( 
	all => \@EXPORT_OK,
	export => [qw(check_and_get_prerequisites)]
);

# use IO::Socket::SSL qw(debug4);

our $Version = 0.2;
my $cfg;
my $absolute_root_dir;
my @handlers;

# Constants
use constant {
    CONFIGURATION_FILENAME  => ".drunner.ini",  
}; 

###
# Docker prerequisites
# TODO: Waiting for https://github.com/alambike/eixo-docker
# FIX: https://coderwall.com/p/siqnjg/disable-tls-on-boot2docker
###

# Get the connection details from our docker host or die

=pod 

=head1 DESCRIPTION

This sub tries to get the right variables for connecting to a local docker daemon

=head1 FUNCTION

This sub gives back an instance of Eixo::Docker::Api

=head 1 METHODS

get_status()

=head1 BUGS

None known

=cut

sub _get_docker_host{
    my $docker_host;
	if ( defined $ENV{DOCKER_HOST} ) {
        $docker_host = Eixo::Docker::Api->new(
		host 		=> "$ENV{DOCKER_HOST}",
		tls_verify 	=> "$ENV{DOCKER_TLS_VERIFY}",
		ca_file 	=> "$ENV{DOCKER_CERT_PATH}/ca.pem",
		cert_file	=> "$ENV{DOCKER_CERT_PATH}/cert.pem",
		key_file 	=> "$ENV{DOCKER_CERT_PATH}/key.pem",
	); } else {
        print "Sadly not a docker-machine-like environment here...\n";
        my $res = parse_netstat(output=>join("", `netstat -tlnp 2> /dev/null`), flavor=>"linux", unix=>0, udp=>0);
        my $docker_port;
        foreach my $value ( @{$res->[2]{active_conns}} ) {
            if ( $value->{local_port} =~ /2375/ ) {
                $docker_port = $value->{local_port};
            };
        };
        defined $docker_port ? $docker_host = Eixo::Docker::Api->new('http://127.0.0.1:2375') : die "Docker port not found\n";
    };

	my %return_values = (
		"docker_handler" , $docker_host
	);
	return wantarray ? %return_values : \%return_values;
}
	

###
# configuration file prerequisites
###


# Idee: Statt Lösung mit Regex lieber Easy-Peasy mit Schnippelfunktionen
# my $dir;
# my @dirlist;

sub _location_of_configuration_ini {
	my $dir = $_[0];	
	my @dirlist;
        
	if ( $dir =~ /^\/$/ ) {
        	push @dirlist, ('/');
	}
	else {
        	push @dirlist, $dir;
        	until ( $dir =~ /^\/$/ ) {
        		my $last_slash;
        		$last_slash = rindex $dir, '/';
        		if ($last_slash == 0) {
                		push @dirlist, ('/');
                		last;
        		}
        		$dir = substr $dir, 0, $last_slash;
        		push @dirlist, $dir;
        	}
	}
	# print Dumper(@dirlist);
	my @configuration_files;
	for (values @dirlist) {
		@configuration_files = File::Find::Rule->file()->name( CONFIGURATION_FILENAME )->in( $_  );
		if ( $#configuration_files >= 0 ) { last; }
	}

	if ( $#configuration_files > 0 ) { die "Error: Multiple configuration files found!"; }

	# print Dumper(@configuration_files);

	if ( -e "$configuration_files[0]" ) {
		# print "Configuration found at $configuration_files[0]\n";
		
        # TODO: Make this into a sub because here we're reading from the configuration file
        $cfg = Config::Tiny->read( "$configuration_files[0]" );
	}
	else {
		die "Error: No configuration file found!";
	}

	# We need to cleanup this path
	# print Dumper(@configuration_files);
	my $full_path_length = length($configuration_files[0]);
	my $configname_length = length(CONFIGURATION_FILENAME);
	my $path_length = $full_path_length - $configname_length;
	$absolute_root_dir = substr $configuration_files[0], 0, $path_length;
	# print Dumper($absolute_root_dir);

	# Let's return a hash instead of manipulating global variables
	my %return_values = (
		"config_handler",     $cfg,
		"absolute_root_dir",  $absolute_root_dir,
	);
	return wantarray ? %return_values : \%return_values;
}

###
# Git prerequisites
# TODO: This is unused except for checking if there's a git repo
###

# We suppose that the configuration file and .git are on the same level
# print Dumper($absolute_root_dir);
sub _initialize_git_repo {
	my $repo = Git->repository ( Directory => $_[0] );
	# if ($repo) {
	# print "Found .git repository under $_[0]" . "\n";
	# } 

	# Let's return a hash instead of manipulating global variables
	my %return_values = ( 
        "git_handler",      $repo 
    );
	return wantarray ? %return_values : \%return_values;
}

sub check_and_get_prerequisites {
	my ($dir) = @_;
	my $docker_handler = _get_docker_host();
	# print Dumper($docker_handler);
	my $config_and_dir = _location_of_configuration_ini($dir);
	my $git = _initialize_git_repo($config_and_dir->{absolute_root_dir});

	my %return_values = (
		"config" , 	  $config_and_dir->{config_handler},
		"git" ,       $git->{git_handler},
		"docker" , 	  $docker_handler->{docker_handler},
		"rootdir", 	  $config_and_dir->{absolute_root_dir},
	);
	return wantarray ? %return_values : \%return_values;

	# push @handlers, $cfg, $docker_host, $repo;
	# return \@handlers;
}


1;

