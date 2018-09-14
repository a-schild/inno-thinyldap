#!/usr/bin/perl
#chkconfig: 345 80 05
#description: LDAP Server for Innovaphone
use strict;
use warnings;

package InnoLdapDaemon;
use Net::Server;
use base 'Net::Server::PreForkSimple';
use Proc::Daemon;
use lib '/var/local/aarldap';
use InnoLdapServer;
use Data::Dumper;
use DateTime;
use File::Pid;

my $debug = 0;
my $logpath= "/var/log/innoldap";
my $dt = DateTime->now;
my $logName= $dt->ymd . '_' . $dt->hms('-');
my $rootHandler= 0;

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

logdebug("Start daemon");
# Start daemon
Proc::Daemon::Init();

open(STDOUT, '>', "$logpath/inno-ldap.$logName.log") or die "Can't open stdout log";
select((select(STDOUT), $|=1)[0]); # make the log file "hot" - turn off buffering
open(STDERR, '>', "$logpath/inno-ldap.$logName.error.log") or die "Can't open error log";
select((select(STDERR), $|=1)[0]); # make the log file "hot" - turn off buffering

my $pidfile = File::Pid->new({file => "/var/run/inno-ldap.pid"});
if ($pidfile->running())
{
	logerror("Daemon already running with this PID");
	die "Already running";
}

$pidfile->write();


# package main;
$rootHandler= InnoLdapDaemon->run(
	port => [ 636, "389/tcp" ],
	proto => "ssl",       # use ssl as the default
	ipv  => "*",          # bind both IPv4 and IPv6 interfaces
	user => "daemon",
    group => "daemon",
	SSL_key_file  => "/home/root/ssl_cert/server.pem",
	SSL_cert_file => "/home/root/ssl_cert/server.pem",
	max_servers => 10,
	log_level => 4
	);

sub process_request {
	my $self = shift;
	
    my $in = *STDIN{IO};
    my $out = *STDOUT{IO};

    my $sock = $self->{server}->{client};
    my $peer_address = $sock->peerhost();
    my $peer_port = $sock->peerport();
    logwarn("Connection accepted from $peer_address : $peer_port");    

	my $handler = InnoLdapServer->new($sock);
	while ($pidfile->running()) 
    {
        my $finished = $handler->handle;
        return if $finished;
	}
}

logdebug("Removing pid file");
$pidfile->remove();

1;
