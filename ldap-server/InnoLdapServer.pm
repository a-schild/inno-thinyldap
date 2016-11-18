#!/usr/bin/perl
#
# @File innoserver.pl
# @Author a.schild
# @Created 17.08.2015 16:54:39
#
#
# Don't make any print statement which go to the console,
# otherwise these prints will also be sent as part of the
# LDAP answer
#


package InnoLdapServer;

use strict;
use warnings;
use diagnostics;
use Data::Dumper;
use DBI;

use lib '../lib';
use Net::LDAP::Constant qw(LDAP_SUCCESS);
use Net::LDAP::Constant qw(LDAP_INVALID_CREDENTIALS);
use Net::LDAP::Constant qw(LDAP_NO_RESULTS_RETURNED);
use Net::LDAP::Server;
use base 'Net::LDAP::Server';
use fields qw();
use Scalar::Util qw(reftype);
use LWP::Simple;
use XML::XPath;
use Cache::FileCache;
use Hash::Util qw(lock_keys unlock_keys unlock_value lock_value);
use fields qw(_userName);

# ---- START CONFIGURATION SECTION ----
my $ldapUserName= 'ldap-user-name';
my $ldapUserPassword= 'ldap-user-password';

my $useTelSearch= 1; # Set to 0 if you not wish to use tel search
my $useDBSearch= 1;  # set to 0 if you not with to use the internal DB

my $apiKeyTelsearch = '<request your own at http://tel.search.ch/api/getkey.en.html>';

my $userid = "<your db user>";
my $password = "<your db password>";

my $debug = 0; # Write more logs to logfile

# ---- END CONFIGURATION SECTION ----
# Usually no need to modify things below this point
my $database = "phonebook_innovaphone";
my $driver = "mysql"; 
my $dsn = "DBI:$driver:database=$database";
my $resolvURLTelsearch = 'http://tel.search.ch/api/?was=';

my $cacheTimeout= 3600; # Number of seconds to cache a tel.search answer

# aliases to make the code more readable for non-perl programmers
sub try(&) { eval {$_[0]->()} }
sub throw($) { die $_[0] }
sub catch(&) { $_[0]->($@) if $@ }
  
  
use constant RESULT_OK => {
    'matchedDN' => '',
    'errorMessage' => '',
    'resultCode' => LDAP_SUCCESS
};

use constant RESULT_LOGIN_FAILED => {
    'matchedDN' => '',
    'errorMessage' => 'Bind failed',
    'resultCode' => LDAP_INVALID_CREDENTIALS
};

use constant RESULT_NOT_FOUND => {
    'matchedDN' => '',
    'errorMessage' => 'Not found',
    'resultCode' => LDAP_NO_RESULTS_RETURNED
};

# constructor
sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    #warn "\nClass: ". Dumper($class);
    #warn "\nSelf : ". Dumper($self);

    #unlock_value(%self);
    #$self->{'_userLogin'}= undef;
    #lock_value(%self);
    return $self;
}

# the bind operation
sub bind 
{
    my $self = shift;
    my $reqData = shift;
    my $userLogin= $reqData->{'name'};
    my $cachePrefix= $userLogin;
    my $authData= $reqData->{'authentication'};
    my $userPW= $authData->{'simple'};
    if ($userLogin eq $ldapUserName && $userPW eq $ldapUserPassword)
    {
	$self->{_userName}= $userLogin;
	return RESULT_OK;
    }
    else
    {
        warn "Bind failed for: " . $userLogin . "\n";
        warn Dumper($reqData);
	warn Dumper($userLogin);
        warn Dumper($authData);
	warn Dumper($userPW);
	return RESULT_LOGIN_FAILED;
    }
}

# the search operation
sub search 
{
    my $self = shift;
    my $reqData = shift;
    my $base = $reqData->{'baseObject'};

    my $userName= $self->{_userName};
    my $cache = new Cache::FileCache( { 'namespace' => $base,
                                        'default_expires_in' => $cacheTimeout } );
    
    # plain die if dn contains 'dying'
    die("panic") if $base =~ /dying/;
    
    # return a correct LDAPresult, but an invalid entry
    return RESULT_OK, {test => 1} if $base =~ /invalid entry/;

    # return an invalid LDAPresult
    return {test => 1} if $base =~ /invalid result/;

    my $searchExpression;
    my $entryFound= 0;
    my @entries;
    if ($reqData->{'scope'}) {
	# onelevel or subtree
	my $myFilter= $reqData->{'filter'};
	logdebug("Full filter definition: " . Dumper($myFilter));
	for my $and(@{$myFilter->{'and'}}) 
        {
	    for my $or (@{$and->{'or'}}) 
	    {
                for my $myORCondition ($or) 
                {
                    logdebug("Found or condition: " . Dumper($myORCondition));
                    my $mySubstrings= $myORCondition->{'substrings'};
                    my $myEquality= $myORCondition->{'equalityMatch'};
                    
                    if (defined($myEquality))
                    {
                        if ($myEquality->{'attributeDesc'} eq "telephoneNumber" )
                        {
			    my $qNumber= $myEquality->{'assertionValue'};
			    $searchExpression= $qNumber;
			    my $result= $self->lookupNumber($qNumber, $userName, $base);
			    if (not defined($result))
			    {
				#logwarn("No match found");
			    }
			    else
			    {
				#logwarn("answer found " . $result);
				push @entries, $result;
				$entryFound= 1;
				last;
			    }
                        }
                    }
                    elsif (defined($mySubstrings))
                    {
			    my $mySubstrings= $mySubstrings;
			    my $type= $mySubstrings->{'type'};
			    my $qNumber= $self->parseSubstring($mySubstrings);
			    if ($type eq 'cn')
			    {
				logwarn("Name0 search not yet implemented for $qNumber");
			    }
			    else
			    {
				$searchExpression= $qNumber;
				my $result= $self->lookupNumber($qNumber, $userName, $base);
				if (not defined($result))
				{
				    #logwarn("No match found");
				}
				else
				{
				    #logwarn("answer found " . $result);
				    push @entries, $result;
				    $entryFound= 1;
				    last;
				}
			    }
                    }
                    else
                    {
			logwarn("Unhandled OR condition Part1 : " . Dumper($myORCondition) );
                    }
                }
		if ( $entryFound >= 1)
		{
		    last;
		}
	    }
	    if ( $entryFound >= 1)
	    {
	        last;
	    }
        }
        
	# Use another search round
        if ($entryFound == 0)
        {
	    logdebug("2Nothing found, using second search method or->or ");
	    logdebug("2Full filter definition: " . Dumper($myFilter));
            for my $or (@{$myFilter->{'or'}}) 
            {
                for my $myORCondition ($or) 
                {
                    logdebug("Found or condition: " . Dumper($myORCondition));
                    my $mySubstrings= $myORCondition->{'substrings'};
                    my $myEquality= $myORCondition->{'equalityMatch'};
                    
                    if (defined($myEquality))
                    {
                        if ($myEquality->{'attributeDesc'} eq "telephoneNumber" )
                        {
			    my $qNumber= $myEquality->{'assertionValue'};
			    $searchExpression= $qNumber;
			    my $result= $self->lookupNumber($qNumber, $userName, $base);
			    if (not defined($result))
			    {
				#logwarn("No match found");
			    }
			    else
			    {
				#logwarn("answer found " . $result);
				push @entries, $result;
				$entryFound= 1;
				last;
			    }
                        }
                    }
                    elsif (defined($mySubstrings))
                    {
			    my $mySubstrings= $mySubstrings;
			    my $type= $mySubstrings->{'type'};
			    my $qNumber= $self->parseSubstring($mySubstrings);
			    if ($type eq 'cn')
			    {
				logwarn("Name0 search not yet implemented for $qNumber");
			    }
			    else
			    {
				my $result= $self->lookupNumber($qNumber, $userName, $base);
				$searchExpression= $qNumber;
				if (not defined($result))
				{
				    #logwarn("No match found");
				}
				else
				{
				    #logwarn("answer found " . $result);
				    push @entries, $result;
				    $entryFound= 1;
				    last;
				}
			    }
                    }
                    else
                    {
			logwarn("Unhandled OR condition Part1 : " . Dumper($myORCondition) );
                    }
                }
		if ( $entryFound >= 1)
		{
		    last;
		}
	    }
	}
	if ($entryFound >= 1)
	{
	    if (defined($searchExpression))
	    {
		logwarn("Found result for $searchExpression : ". Dumper(@entries));
	    }
	    else
	    {
		logwarn("Found result : ". Dumper(@entries));
	    }
	}
	else
	{
	    if (defined($searchExpression))
	    {
		logwarn("No entries found: ".$searchExpression);
	    }
	    else
	    {
		logwarn("No entries found: ".Dumper($myFilter));
	    }
	}
    }
    if ($entryFound >= 1)
    {
	return RESULT_OK, @entries;
    }
    else
    {
	return RESULT_NOT_FOUND;
    }
}



sub queryTelSearch()
{
    my $retVal;
    my $self = shift;
    my $qNumber = shift;
    my $originalSearchNR= $qNumber;
    my $base = shift;
    my $cache = new Cache::FileCache( { 'namespace' => 'telsearch-' . $base,
                                        'default_expires_in' => 3600 } );

    logdebug("Telsearch Resolve NR " . $qNumber);
    my $response= $cache->get( $qNumber );
    if (not defined ($response))
    {
        my $fullURL= $resolvURLTelsearch . $qNumber . '&key=' . $apiKeyTelsearch;
	#my $fullURL= $resolvURLTelsearch . "0323310905";
        logwarn("Query tel.search for: ".$fullURL);
	$response = get $fullURL;
        logwarn("Storing TelSearch answer in cache: ".$response);
	$cache->set($qNumber, $response);
    }
    else
    {
        logdebug("TelSearch answer from cache: ".$response);
    }

    my $xp = XML::XPath->new( xml => $response );
    #warn "Created parser $xp\n";

    try
    {
	my $entries = $xp->find( '/feed/entry' );
	#warn "Nodes searched $entries\n";

	foreach my $entry( $entries->get_nodelist ) {
	    logdebug("Node found");
	    my $id   = $xp->find( 'tel:id',  $entry )->string_value;
	    my $title   = $xp->find( 'title',  $entry )->string_value;
	    my $content = $xp->find( 'content', $entry )->string_value;
	    
	    my $name= $xp->find( 'tel:name', $entry )->string_value;
	    my $firstname= $xp->find( 'tel:firstname', $entry )->string_value;
	    my $zip= $xp->find( 'tel:zip', $entry )->string_value;
	    my $city= $xp->find( 'tel:city', $entry )->string_value;
	    my $canton= $xp->find( 'tel:canton', $entry )->string_value;
	    #my $phone = $xp->find( 'tel:phone', $entry )->string_value;
	    my $phone= $originalSearchNR;
	    logdebug("Titel: " .$title );
	    logdebug("Phone: " .$phone );
	    logdebug("Content: " .$content );
	    logdebug("Name: " .$name );
	    logdebug("FirstName: " .$firstname );
	    logdebug("Zip: " .$zip );
	    logdebug("City: " .$city );
	    logdebug("Canton: " .$canton );
	    my $dnPart= "cn=telsch_".$id ;
	    my $myDN= $dnPart.",". $base;
	    my $foundEntry = Net::LDAP::Entry->new;
	    my $cn= trim($name . ' ' . $firstname) . ', ' . $zip . ' ' .$city;
	    if (defined($canton) && length $canton > 0)
	    {
		    $cn= $cn . '/' . $canton;
	    }
	    logwarn("dn: " .$myDN );
	    logwarn("cn: " .$cn );
	    $foundEntry->dn($myDN);
	    $foundEntry->add(
			    dn => $dnPart,
			    sn => $title,
			    cn => $cn,
			    telephoneNumber => [$phone]
			    );
	    $retVal= $foundEntry;
	}
    };
    catch {
	logwarn("Exception TelSearch no match found for: ".$qNumber. " " . $@);
    };
    if (not defined($retVal))
    {
	logwarn("TelSearch not found: ".$qNumber);
    }
    return $retVal;
}


sub queryMySQL()
{
    my $retVal;
    my $self = shift;
    my $qNumber = shift;
    my $originalSearchNR= $qNumber;
    my $base = shift;
    my $cache = new Cache::FileCache( { 'namespace' => 'telsearch-' . $base,
                                        'default_expires_in' => 3600 } );

    if (index($qNumber, '+') == 0)
    {
        # $qNumber= substr($qNumber, 1);
    }
    else
    {
        if (index($qNumber, "000") ==0)
        {
            $qNumber= '+'. substr($qNumber, 3);
        }
        elsif (index($qNumber, "00") ==0)
        {
            $qNumber= "+41".substr($qNumber, 2);
        }
    }

    logdebug("MySQL Resolve NR " . $qNumber);
    my $dbh = DBI->connect($dsn, $userid, $password ) or die $DBI::errstr;
    
    my $sth = $dbh->prepare("SELECT addressid, person, company
			    FROM address
			    WHERE phone = ? or mobil=? ");
    $sth->execute( $qNumber, $qNumber ) or die $DBI::errstr;
    logmsg("Number of rows found :" . $sth->rows);
    while (my @row = $sth->fetchrow_array()) {
       my ($addressid, $person, $company) = @row;
       logmsg("id= $addressid, Person = $person, Company = $company");

	my $dnPart= "cn=mysql_".$addressid;
	my $myDN= $dnPart .",". $base;
	my $foundEntry = Net::LDAP::Entry->new;
	my $cn= "";
	if (defined($person) && length $person > 0)
	{
		$cn= $person;
	}
	if (defined($company) && length $company > 0)
	{
	    if (length $cn > 0)
	    {
		$cn= $cn . ', ' . $company;
	    }
	    else
	    {
		$cn= $company;
	    }
	}
	logwarn("dn: " .$myDN );
	logwarn("cn: " .$cn );
	$foundEntry->dn($myDN);
	$foundEntry->add(
			dn => $dnPart,
			sn => $cn,
			cn => $cn,
			telephoneNumber => $qNumber
			);
	$retVal= $foundEntry;

    }
    $sth->finish();
    
    if (not defined($retVal))
    {
	logwarn("SearchMySQL not found: ".$qNumber);
    }
    
    return $retVal;
}

sub lookupNumber()
{
    my $self = shift;
    my $qNumber = shift;
    my $userName= shift;
    my $base= shift;
    
    my $retVal;
    my $entryFound= 0;
    
    logwarn("Lookup number $qNumber for $userName in context $base");
    
    if ($useDBSearch == 1 )
	{
		logdebug("Query MySQL for $qNumber");
		my $answer= $self->queryMySQL($qNumber, $base);
		if (not defined($answer))
		{
			logdebug("No answer in mySQL");
		}
		else
		{
			logdebug("answer in mySQL " . $answer);
			$retVal= $answer;
			$entryFound= 1;
		}
	}

    if ($useTelSearch == 1 )
	{
		if ($entryFound == 0 && index($qNumber, '+41') == 0 && length $qNumber > 10 && length $qNumber < 14 )
		{
			logdebug("Query tel.search for $qNumber");
			my $answer= $self->queryTelSearch($qNumber, $base);
			if (not defined($answer))
			{
				logdebug("No answer in tel.search");
			}
			else
			{
				logdebug("answer in tel.search " . $answer);
				$retVal= $answer;
				$entryFound= 1;
			}
		}
	}
    
    return $retVal;
}


sub parseSubstring()
{
    my $self = shift;
    my $substringQuery = shift;
    my $retVal= "";
    my $myRealArray= $substringQuery->{'substrings'};
    for my $el ($myRealArray) 
    {
	foreach my $val (values $el) 
	{
	    foreach my $val1 (values $val) 
	    {
		$retVal.= $val1;
	    }
	}
    }
    # logwarn("Returning $retVal for " . Dumper($substringQuery));
    return $retVal;
}

sub logmsg {
  print STDERR (scalar localtime() . " @_\n");
}

sub logwarn {
  warn scalar localtime() . " @_\n";
}

sub logerr {
  print STDERR (scalar localtime() . "ERROR: @_\n");
}

sub logdebug {
  if ($debug) {
    print STDERR (scalar localtime() . ":DEBUG: @_\n");
  }
}

sub  trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s };

# the rest of the operations will return an "unwilling to perform"

1;