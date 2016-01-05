package dRunner::Virtualbox;

# Boilerplate
use warnings;
use strict;
# use diagnostics;
# use v5.12;
use experimental 'autoderef', 'smartmatch', 'switch'; 
use Data::Dumper;
use autodie;

use Term::ANSIColor;

use Exporter 'import';
our @EXPORT_OK = qw(
    _get_virtualbox_forwardings
    _get_docker_forwardings
	_check_forwardings
	print_forwarded_ports
	forward_ports
	remove_forwardings	
);
# print Dumper(@EXPORT_OK);
our %EXPORT_TAGS = (
        all => \@EXPORT_OK,
        export => [qw(print_forwarded_ports forward_ports remove_forwardings)]
);

my $virtualbox 	= "VBoxManage";
my $vm_name 	= "default";

# use Eixo::Docker::Api;
# use forks;
# my $docker_http_host = $ENV{DOCKER_HOST};
# $docker_http_host =~ s/tcp/http/;
# my $docker_host = Eixo::Docker::Api->new($docker_http_host);
# my $container = $docker_host->containers->get( id => "b6055cacbc06" );

# =pod

# =head1 

# Virtualbox.pm

# =cut

sub _get_virtualbox_forwardings{
	my $output = qx/$virtualbox "showvminfo" $vm_name "--machinereadable"/;
	my @return_values;
	open my $fh, '<', \$output or die;
	while ( my $line = <$fh> ) {
        	if ($line =~ /^Forwarding\(\d+\)="(.*)"/) {
               	# print $1 . "\n";

                my @sanitized = split /,/,$1;
                # print Dumper(@sanitized);
                push @return_values, {
                        name            	=> $sanitized[0],
                        protocol        	=> $sanitized[1],
                        host_ip         	=> $sanitized[2],
                        host_port       	=> $sanitized[3],
                        docker_host_ip        	=> $sanitized[4],
                        docker_host_port      	=> $sanitized[5],
                };
                # print Dumper(%array);
        	}
	}
	close $fh;
	return wantarray ? @return_values : \@return_values ;
}

=pod

=head1 NAME 

_get_docker_forwardings

=head1 DESCRIPTION

This sub returns all forwardings we have arranged for the actual container

=head1 FUNCTION

This sub expects a handler from Eixo::Docker::Api and returns an array which values are hashes (AoH) like this:

$VAR1 = [
          {
            'protocol' => 'tcp',
            'docker_host_port' => undef,
            'container_port' => '80',
            'docker_host_ip' => undef
          },
          {
            'protocol' => 'tcp',
            'docker_host_port' => undef,
            'container_port' => '3306',
            'docker_host_ip' => undef
          }
        ];

=head1 BUGS

The sub doesn't check if the handler is the right one

=cut

sub _get_docker_forwardings{
	my $docker = $_[0];
	# print Dumper($docker);
	# print Dumper($docker->{Config}{ExposedPorts});
	my @return_values;
	#print ref($docker) . "\n";
	#print Dumper($docker);
	#my $forwards = $docker->{NetworkSettings}{Ports};
	#print Dumper($docker->{NetworkSettings}{Ports});
	# print Dumper($_[1]);
	# my $docker = \$_[0];
	foreach (keys $docker->{Config}{ExposedPorts}) {
        	# my $index = index $_, '/';
        	# my $key = substr $_, 0, $index;
        	my ($container_port, $protocol) = split '/', $_;
        	# print $container_port . "\n";
        	push @return_values, {
                	container_port         	=> $container_port,
                	protocol                => $protocol,
                	docker_host_port        => $docker->{NetworkSettings}{Ports}{$_}[0]{HostPort},
                	docker_host_ip          => $docker->{NetworkSettings}{Ports}{$_}[0]{HostIp}
        	};	
	};
	return wantarray ? @return_values : \@return_values ;
}

sub _check_forwardings {
	# We want a straight connection from our docker container to the host
	# This subfunction checks for this
	my $docker_ports = _get_docker_forwardings($_[0]);
	my $virtualbox_ports = _get_virtualbox_forwardings();
	# print Dumper($docker_ports);
	# print Dumper($virtualbox_ports);
	my %return_values;

	foreach my $port (values $docker_ports) {
		# print $port . "\n";
		foreach my $host (values $virtualbox_ports) {
			# print $host . "\n";
			if ( $port->{docker_host_port} == $host->{docker_host_port} ) {
				$return_values{ $port->{container_port} } = "$host->{host_port}";
				last;
			}
			else {
				$return_values{ $port->{container_port} } = undef;
			}
		};
	};
	# print Dumper(%return_values);
	return wantarray ? %return_values : \%return_values;
}


sub print_forwarded_ports {
	my $forwardings = _check_forwardings($_[0]);
	my $missing;
	foreach my $container_port (keys $forwardings) {
		if (defined $forwardings->{$container_port}) {
			given ($container_port) {
				when ('80') {	
					print "The webserver is " . colored("forwarded", 'green') . ": http://localhost:$forwardings->{$container_port}/\n";
				}
				when ('3306') {
					print "The mysql is " . colored("forwarded",'green') . ": mysql://localhost:$forwardings->{$container_port}/\n";
				}
			}
		}
		else {
			$missing = "true";	
			given ($container_port) {
				when ('80') {
					print "The forwarding for the webserver is " . colored("missing\n", 'red');
				}
				when ('3306') {
					print "The forwarding for the mysql server is " . colored("missing\n", 'red');
				}
			}
		}
	}	
	if (defined $missing) {
		print colored("Missing forwardings detected! ", 'magenta') . "Run the script with the param \"fix\"\n";
	}
}

=pod

=head1 NAME

forward_ports

=head1 DESCRIPTION

This sub installs the desired forwardings from the local host to the container ports

=head1 FUNCTION

This sub expects the handlers $docker and $config like this: forward_ports($docker, $config);

=head1 BUGS

=over 4

=item - The sub doesn't check if the right handlers were given

=item - The sub assumes that the binary VBoxManage is in $PATH

=back

=cut

sub forward_ports {
	my ($docker, $config) = @_;
	# print Dumper($docker);
	my $forwardings = _check_forwardings($docker);
	foreach my $container_port (keys $forwardings) {
		if ( not defined $forwardings->{$container_port} ) {
			my $designated_port;
			my $random_high_port = sub {
        			my $number;
        			do { $number = int(rand(65536)); } while $number < 1024;
        			return $number; 
			};
			# print &$random_high_port . "\n";

			# Docker manages the container_port <=> docker_host_port for us
			# We have to take care of docker_host_port <=> host_port
			
			until ( defined $designated_port ) {
				my $number = &$random_high_port;
				my @forwarded_ports;
				foreach ( values _get_virtualbox_forwardings() ) {
					push @forwarded_ports , $_->{host_port};	
				}
				if ( grep /$number/, @forwarded_ports ) { redo; }
				else { $designated_port = $number; }
			}
			print "We can use $designated_port on the host for forwarding to our docker container port $container_port" . "\n";

			# Fun Fact: We don't know which port docker has assigned
			# Let's find out...
			my $docker_host_port = sub {
				my $docker_forwardings = _get_docker_forwardings($docker);
				my $return_value;
				foreach my $hash ( values $docker_forwardings ) {
					#print Dumper($hash);
					if ( $hash->{container_port} == $container_port ) {
						$return_value = $hash->{docker_host_port};
					}
				}
				return $return_value;
			};
						
			# print &{$docker_host_port} . "\n";
				

			my @services = split /,/, $config->{_}{services}; 
			my $service_name;
			foreach ( values @services ) {
				if ( $config->{$_}{container_port} == $container_port ) {
					$service_name = $config->{$_}{name};
				}
			}
			my $unique_id = substr $config->{_}{container_id}, 0, 12 ; 
			$unique_id .= "-" . $service_name;

			my $designated_docker_host_port = &{$docker_host_port};
			#print "The planned identifier for virtualbox is $unique_id\n";
			#print "The name of the service is $service_name\n";
			qx($virtualbox controlvm $vm_name natpf1 "${unique_id},tcp,127.0.0.1,${designated_port},,${designated_docker_host_port}");
			( $? != 0 ) ? die "Virtualbox failed to execute\n" : print colored("Forwarding implemented successfully!\n", 'green');
		}
	} 
}

=pod

=head1 NAME

remove_forwardings

=head1 DESCRIPTION

This sub removes all forwardings for this project/config

=head1 FUNCTION

The sub expects the handler for the config and return an informational message on success or dies if VBoxManage failed somehow

=head1 BUGS

This sub doesn't check for the right handlers
		
=cut

sub remove_forwardings {
	my ( $config ) = @_;
	my $unique_id = substr $config->{_}->{container_id}, 0, 12;
	my $output = qx/$virtualbox "showvminfo" $vm_name "--machinereadable"/;
	open my $handle, '<', \$output or die $!;
	while ( <$handle> ) {
        	if ($_ =~ /${unique_id}/) {
			my $id = $_;

			# This feels crappy
                	$id =~ s/.*="(.*?),.*/$1/;
			chomp $id;

			my $service = $id;
			$service =~ s/.*-(.*)/$1/;
                	qx/$virtualbox controlvm $vm_name natpf1 delete $id/;
                	( $? != 0 ) ? die "Virtualbox failed to execute\n" : print "Forwarding for $config->{$service}->{name} removed successfully\n";

        	}
	}
}

		

		

# print_forwarded_ports();

# _check_forwardings($container);

# forward_ports();
	

# my $output = _get_forwardings();
# print Dumper($output);

# my $docker_forwardings = _get_docker_forwardings();
# print Dumper($docker_forwardings);
# my $virtualbox_forwardings = _get_virtualbox_forwardings();
# print Dumper($virtualbox_forwardings);



1;
