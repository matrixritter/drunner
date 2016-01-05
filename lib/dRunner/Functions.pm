package dRunner::Functions;

# Boilerplate
use warnings;
use strict;
# use diagnostics;
# use v5.12;
use experimental 'autoderef', 'smartmatch', 'switch'; 
use Data::Dumper;
use autodie;

# use Git;
# use Config::Tiny;

# use Eixo::Docker::Api;
# use File::Find::Rule;

use Exporter 'import';
our @EXPORT_OK = qw(
	get_container_status
	_exec_container
    exec_and_save_container_command
    dump_db
);
# print Dumper(@EXPORT_OK);
our %EXPORT_TAGS = ( 
	all => \@EXPORT_OK,
	export => [qw(get_container_status exec_and_save_container_command dump_db)]
);

our $Version = 0.1;

=pod

=head1 NAME

get_container_status

=head1 DESCRIPTION

This sub returns a hash with infos to the running container

=head1 FUNCTION

This sub checks the configuration file for container_id or, if missing, container_name. Then the docker-handler is asked for more information.

=head1 BUGS

Not really a bug hint, but this sub does really very little. Idea: Return a hash with structured information or a number which kann be interpreted as specific error code.

=cut

sub get_container_status {
	my ( $docker, $config ) = @_;
	my $container;
        if (defined $config->{_}->{container_id} && $config->{_}->{container_id} =~ /[[:alpha:]]+/ ) {
        	eval { $container = $docker->containers->status( id => "$config->{_}->{container_id}" ) };
        }       
        elsif (defined $config->{_}->{container_name} && $config->{_}->{container_name} =~ /[[:alpha:]]+/ ) {
        	eval { $container = $docker->containers->getByName( $config->{_}->{container_name} ) };
		# We have to go the extra mile here...
		$container = $container->{State};
	}
	return $container;
}

=pod

=head1 NAME

dump_db()

=head1 DESCRIPTION

This sub executes the appropriate dump-application in the docker container

=head1 FUNCTION 

By using the Exec-Method from docker we generate appropriate output without relying on the host's capabilities.

=head1 BUGS

None known

=cut

sub dump_db {
	my ( $config, $db, $db_type) = @_;
	my $output;
	given($db_type) {
		when('mysql') { $output = _exec_container($config, "mysqldump -u root --databases $db"); }
		when('postgres') { }
	}
	return $output;
}

=pod

=head1 NAME

_exec_container()

=head1 DESCRIPTION

This sub executes something in the given container and returns the output

=head1 FUNCTION

The sub takes two arguments:

- Handler to the configuration: $config
- Actual command to be executed: $exec

See DESCRIPTION

=head1 BUGS

Might use a lot of memory which huge outputs

=cut

sub _exec_container {
	my ( $config, $command ) = @_;
	my $container;
    if (defined $config->{_}->{container_id} && $config->{_}->{container_id} =~ /[[:alpha:]]+/ ) {
     	$container = $config->{_}->{container_id};
    }       
    elsif (defined $config->{_}->{container_name} && $config->{_}->{container_name} =~ /[[:alpha:]]+/ ) {
		$container = $config->{_}->{container_name};
	}
	my $output = qx/docker exec -it $container $command/;
	return $output;
}



# This is just for testing

sub exec_and_save_container_command {
	my ( $docker, $config, $command, $outputfile ) = @_;
	my $container;
        if (defined $config->{_}->{container_id} && $config->{_}->{container_id} =~ /[[:alpha:]]+/ ) {
        	$container = $config->{_}->{container_id};
        }       
        elsif (defined $config->{_}->{container_name} && $config->{_}->{container_name} =~ /[[:alpha:]]+/ ) {
		$container = $config->{_}->{container_name};
	}
	my $output = qx/docker exec -it $container $command/;
	#print Dumper($container);
	#print Dumper($output);

	open ( my $fh, '+>', $outputfile ) or die;
	print $fh $output;
	close $fh or die;
}


1;

