#!/usr/bin/perl
#chkconfig: 345 80 05
#description: LDAP Server for Innovaphone
use strict;
use warnings;

package Listener;
use Net::Server;
use base 'Net::Server::Fork';

use lib '/var/local/aarldap';
use InnoLdapServer;
use Data::Dumper;
#use Scalar::Util qw/openhandle/;

sub process_request {
	my $self = shift;
	
    my $in = *STDIN{IO};
    my $out = *STDOUT{IO};

    my $sock = $self->{server}->{client};
    
    my $peer_address = $sock->peerhost();
    my $peer_port = $sock->peerport();
    warn "Connection accepted from $peer_address : $peer_port \n";    

    #print STDERR 'in = ('.openhandle($in).') '.Dumper($in);
    #print STDERR 'out = ('.openhandle($out).') '.Dumper($out);
	my $handler = InnoLdapServer->new($sock);
	#my $handler = InnoLdapServer->new($in,$out);
	while (1) 
        {
            my $finished = $handler->handle;
            return if $finished;
	}
}




Listener->run(port => 389);

1;
