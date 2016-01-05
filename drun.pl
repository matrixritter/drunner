#!/usr/bin/env perl

# Boilerplate
use warnings;
use strict;
# use diagnostics;
# use v5.12;
use experimental 'autoderef', 'smartmatch','switch'; 
use Data::Dumper;
use autodie;

use JSON::PP;
use Cwd;
use Git;
use Term::ANSIColor;

# This should be unneeded in this file
#use Config::Tiny;
#use Eixo::Docker::Api;
#use File::Find::Rule;


# Own functions
use lib 'lib';
use dRunner::Prereq qw(:export);
use dRunner::Functions qw(:export);
use dRunner::Virtualbox qw(:export);

my $own_name = "dRunner";
my $version = 0.2;
my $dir = getcwd;
my $handlers = check_and_get_prerequisites($dir);
# print Dumper($handlers);
my $action = $ARGV[0];

# Constants
use constant {
    CONFIGURATION_FILENAME  => ".drunner.ini",  
}; 

# A little introduction
print "This is $own_name!\n";
print "Version $version" . "\n";
print "\n";

=pod

=head1 DESCRIPTION

This sub checks if the required handlers (Docker, Virtualbox, Git) are there and if the container is running

=head1 FUNCTION

This sub gives the user an overview of the current status of everything

=head1 METHODS

get_status()

=head1 BUGS

=over 4

=item - The error message is most likely correct but could be a hint for a broken configuration file too

=back

=cut

sub get_status() {
	if (defined $handlers) {
		print "All prerequisites fullfilled: " . colored("OK", 'green') . "\n";
	}
	else {
		print "Broken handlers: " . colored("CRITICAL", 'red');
	}
	
	my $status = get_container_status( $handlers->{docker}, $handlers->{config} ); 
	if ( defined $status ) {
		print "Docker Container is running: " . colored("OK", 'green') . "\n";
	}
	else {
		print colored("Docker Container is not running", 'red') . " - You can start it with the subcommand " . colored("run\n", 'magenta');
	}
}

sub pull_repo() {

	# my $pull 	= $repo->command('pull');
}

sub commit_repo() {}

sub show_config {
	my $config = $handlers->{config};
	my @services = split /,/, $config->{_}{services};
	print Dumper(@services);	
	print Dumper($config);
	print "Your intended image is $config->{_}{repository}:$config->{_}{tag}\n";
	my $intended_status;
	if ( defined $config->{_}{container_status} ) { $intended_status = "should"; }
	else { $intended_status = "will"; }
	foreach (values @services) {
		print "You have a $config->{$_}{name} service defined which $intended_status listen on ". ( uc $config->{$_}{type} ) . "-port $config->{$_}{container_port} \n";
	}
}

=pod

=head1 NAME

run_docker

=head1 DESCRIPTION

This sub creates a container according to the configuration file

=head1 FUNCTION

This sub grabs all handlers $handlers, starts a container, setups the forwardings and gives some output

=head1 METHODS

run_docker()

=head1 BUGS

None known

=cut

sub run_docker{
	# require forks;
	my ( $docker, $config, $rootdir ) = ( $handlers->{docker}, $handlers->{config}, $handlers->{rootdir} );
	# print Dumper($docker);
	# print Dumper($config);
	my $image = "$config->{_}->{repository}" . ":" . "$config->{_}->{tag}";

	# Take all service-blocks
	my @services = split /,/, $config->{_}{services};
	my %hash;
	foreach ( values @services ) {
		my $port = $config->{$_}{container_port};
		my $type = $config->{$_}{type};
		my $key = $port . "/" . $type;
		$hash{${key}} = {} ;
	}

	# Take all mount-blocks
	# Problem: This needs absolute paths
	# Solution: I have it in $rootdir ;D
	my @mounts = split /,/, $config->{_}->{mounts};
	my @array;
	foreach ( values @mounts ) {
		my $dir = $_;
		# print $dir . "\n";
		# print Dumper($config->{$dir});
		my $fulldir = $rootdir . "/" . $config->{$dir}{host_directory} . ":" . $config->{$dir}{container_mount};
		push @array, $fulldir;
		print "Will try to mount " . $rootdir . "/" . $config->{$dir}{host_directory} . " to " . $config->{$dir}{container_mount} . " in the container\n";
		$config->{$dir}{mounted}="true";
	}
	# print Dumper(@array); 	
	# print Dumper(%hash);
	my $port_ref = \%hash;
	my $mount_ref = \@array;	
	my $container = $docker->containers->create(
		Image 		=> $image,
		NetworkDisabled => JSON::PP->false,
		ExposedPorts 	=> $port_ref,
		HostConfig 	=> {
				Binds => $mount_ref,
				
		},
		# Entrypoint => "/bin/bash",
	);
	#print Dumper($container);
	# print Dumper($docroot);
	$container->start(
			"PublishAllPorts"	=> JSON::PP->true,
	);

	
	# Save variables
	# print Dumper($rootdir);
	$config->{_}->{container_name} = $container->{Name};
	$config->{_}->{container_status} = "running";
	$config->{_}->{container_id} = $container->{Id};
	$config->write( ${rootdir} . '/' . CONFIGURATION_FILENAME );

	print "Started container\n";

	# Make it work!
	# Problem: $container doesn't really carries what we need(?)
	# Workaround:
	my $container_id = $config->{_}->{container_id};
	my $started_container = $docker->containers->get(id => $container_id );
	#print Dumper($started_container);
	forward_ports($started_container,$config);

	# We need our files in the container

	#print Dumper($container);
	#my $forwards = _get_docker_forwardings($started_container);
	#print Dumper($forwards);
}
	
=pod

=head1 NAME

stop_docker

=head1 DESCRIPTION

This sub stops the running container

=head1 FUNCTION

This sub grabs the three handlers $handlers to stop the container, remove the forwardings and clean the configuration

=head1 METHODS

stop_docker()

=head1 BUGS

None known

=cut

sub stop_docker{
	my ( $docker, $config, $rootdir ) = ( $handlers->{docker}, $handlers->{config}, $handlers->{rootdir} );

		my $container;
		# print Dumper($config);
		if (defined $config->{_}->{container_id} && $config->{_}->{container_id} =~ /[[:alpha:]]+/ ) {
			# print "container_id is defined" . "\n";
			$container = $docker->containers->get( id => "$config->{_}->{container_id}" );
		}
		elsif (defined $config->{_}->{container_name} && $config->{_}->{container_name} =~ /[[:alpha:]]+/ ) {
			# print "container_name is defined" . "\n";
			$container = $docker->containers->getByName( $config->{_}->{container_name} );
	}
	else {
		die "No running container" . "\n";
	}

	# print Dumper($container);
	print "Stopping Container" . "\n";
	$container->stop();
	print colored("Container stopped\n", 'green');

	print "Remove forwardings" . "\n";
	remove_forwardings($config);
	
	delete $config->{_}->{container_name};
	delete $config->{_}->{container_status};
	delete $config->{_}->{container_id};
	$config->write( ${rootdir} . '/' . CONFIGURATION_FILENAME );
	
}

=pod

=head1 NAME

dump_databases

=head1 DESCRIPTION

This sub dumps all configured databases

=head1 FUNCTION

All configured databases are dumped by executing a command inside the container and writing the output to the specified directory

=head1 BUGS

None known
	
=cut
	
sub dump_databases{
	my ( $docker, $config, $rootdir ) = ( $handlers->{docker}, $handlers->{config}, $handlers->{rootdir} );
	my @databases = split /,/, $config->{_}->{databases};
	# my $output;
	for my $db (values @databases) {
		print "The database named $db has the type $config->{$db}->{type}\n";
		my $db_type = $config->{$db}->{type};
		my $output = dump_db($config, $db, $db_type);
		my $outputfile = $rootdir . "/dumps/" . $db . ".sql";
		print "Output should be written to $outputfile\n";
		open ( my $fh, '+>', $outputfile ) or die;
		print $fh $output;
		close $fh or die;
		print "Dumped database $db successfully!\n";
	};
}
	

###
# TODO: Use proper module for argument handling
###

given ($action) {
	when ('status') {
		get_status();
	}
	when ('pull') {
		pull_repo();
	}
	when ('commit') {
		commit_repo();
	}
	when ('run') {
		run_docker();
	}
	when ('stop') {
		stop_docker();
	}
	when ('config') {
		show_config();
	}
	when ('dump') {
		dump_databases();
	}
	when ('test') {
		my $command = "mysqldump --all-databases | gzip -c -";
		my $outputfile = "/Users/kkruse/dump.sql.gz";
		exec_and_save_container_command( $handlers->{docker}, $handlers->{config}, $command, $outputfile );
	}
		
}

# Cleanup

# $cfg->write("$absolut_ini[0]");
