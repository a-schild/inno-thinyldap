#!/usr/bin/perl
#chkconfig: 345 80 05
#description: LDAP Server for Innovaphone
use strict;
use warnings;

package Listener;
use Net::Server;
use base 'Net::Server::Fork';
use Proc::Daemon;
use lib '/var/local/aarldap';
use InnoLdapServer;
use Data::Dumper;
use DateTime;
#use Scalar::Util qw/openhandle/;

my $debug = 0;
my $logpath= "/var/log/innoldap";
my $dt = DateTime->now;
my $logName= $dt->ymd . '_' . $dt->hms('-');


sub process_request {
	my $self = shift;
	
    my $in = *STDIN{IO};
    my $out = *STDOUT{IO};

    my $sock = $self->{server}->{client};
    my $peer_address = $sock->peerhost();
    my $peer_port = $sock->peerport();
    logwarn("Connection accepted from $peer_address : $peer_port");    

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


Proc::Daemon::Init;

my $continue = 1;
$SIG{TERM} = sub { $continue = 0 };

open(STDOUT, '>', "$logpath/inno-ldap.$logName.log") or die "Can't open stdout log";
open(STDERR, '>', "$logpath/inno-ldap.$logName.error.log") or die "Can't open error log";

while ($continue) {
package main;


Listener->run(port => 389);
}


sub logmsg {
  print (scalar localtime() . " @_\n");
}

sub logwarn {
  warn scalar localtime() . " @_\n";
}

sub logerr {
  print STDERR (scalar localtime() . "ERROR: @_\n");
}

sub logdebug {
  if ($debug) {
    print "DEBUG: @_\n";
  }
}

1;
