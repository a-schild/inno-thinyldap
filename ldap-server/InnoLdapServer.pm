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
use utf8;
use encoding 'utf8';

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
use Net::LDAP::Util qw/escape_dn_value/;
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

my $speedDialPrefix= "70"; # Add this in front of number to speed dial searches
my $gigasetInternationalPrefix= "000"; # Replace + sign in front of numbers with these numbers
my $gigasetRemoveUmlauts= 0; # Remove common umlauts from results to fix gigaset ldap problems

# ---- END CONFIGURATION SECTION ---- 
# Usually no need to modify things below this point
my $database = "phonebook_innovaphone";
my $driver = "mysql"; 
my $dsn = "DBI:$driver:database=$database";
my $resolvURLTelsearch = 'http://tel.search.ch/api/?was=';

my $debug = 0; # Write more logs to logfile, set to 1
my $logTrace = 0; # Write even more logs to logfile, set to 1
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
    my ($self, $reqData) = @_;
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
        logwarn("Bind failed for: " . $userLogin);
        logwarn(Dumper($reqData));
		logwarn(Dumper($userLogin));
        logwarn(Dumper($authData));
		logwarn(Dumper($userPW));
		logwarn("Bind failed for: " . $userLogin);
		return RESULT_LOGIN_FAILED;
    }
}

# the search operation
sub search 
{
    my ($self, $reqData) = @_;
    my $base = $reqData->{'baseObject'};
    my $sizeLimit = $reqData->{sizeLimit};
    if ($sizeLimit <= 0)
    {
        $sizeLimit= 40;
    }
    my $userName= $self->{_userName};
    my $cache = new Cache::FileCache( { 'namespace' => $base,
                                        'default_expires_in' => $cacheTimeout } );
    logdebug("Request data: " . Dumper($reqData));

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
        if (!$self->isSpeedDial($base))
        {
	    logdebug("No speed dial query");
            for my $and(@{$myFilter->{'and'}}) 
            {
				logdebug("AND1 query loop");
				if (exists $and->{'or'})
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
								if (
								    $myEquality->{'attributeDesc'} eq "telephoneNumber"
									|| $myEquality->{'attributeDesc'} eq "mobile"
									|| $myEquality->{'attributeDesc'} eq "homePhone"
									)
								{
									my $qNumber= $myEquality->{'assertionValue'};
									$searchExpression= $qNumber;
									my $result= $self->lookupNumber($qNumber, $userName, $base);
									if (not defined($result))
									{
										logdebug("No match found $qNumber");
									}
									else
									{
										logdebug("answer found " . Dumper($result));
										push @entries, $result;
										$entryFound= 1;
										last;
									}
								}
					else
					{
					loginfo("Not query for equality1");
					}
							}
							elsif (defined($mySubstrings))
							{
									my $mySubstrings= $mySubstrings;
									my $type= $mySubstrings->{'type'};
									my $qNumber= $self->parseSubstring($mySubstrings);
									if (!(
                                            $myEquality->{'attributeDesc'} eq "telephoneNumber" 
                                            || $myEquality->{'attributeDesc'} eq "mobile"
                                            || $myEquality->{'attributeDesc'} eq "homePhone"
                                       ))
									{
										$searchExpression= $qNumber;
										@entries= $self->lookupNames($searchExpression, $userName, $base, $sizeLimit);
										if (scalar(@entries) == 0)
										{
											logdebug("No match found $searchExpression");
										}
										else
										{
											logdebug("answer found " . Dumper(@entries));
											#push @entries, $result;
											$entryFound= 1;
											last;
										}
									}
									else
									{
										$searchExpression= $qNumber;
										my $result= $self->lookupNumber($qNumber, $userName, $base);
										if (not defined($result))
										{
											logdebug("No match found $qNumber");
										}
										else
										{
											logdebug("answer found " . $result);
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
				else
				{
					# Not in and->or nesting
					logdebug("Found and condition without nested or: " . Dumper($and));
					my $mySubstrings= $and->{'substrings'};
					logdebug("Substrings1: " . Dumper($mySubstrings));
					for my $mySubstrings2 (@{$mySubstrings->{'substrings'}}) 
					{
					logdebug("Substrings2: " . Dumper($mySubstrings2));
					my $searchExpression= $mySubstrings2->{'initial'};
					logdebug("myInitial: " . Dumper($searchExpression));
					my $type= $mySubstrings->{'type'};
					logdebug("type: " . Dumper($type));
					if (
                                $type eq 'company' || 
                                $type eq 'givenName' || 
                                $type eq 'sn'
                                )
					{
						@entries= $self->lookupNames($searchExpression, $userName, $base, $sizeLimit);
						if (scalar(@entries) == 0)
						{
						logdebug("No match found $searchExpression");
						}
						else
						{
						logdebug("answer found " . Dumper(@entries));
						#push @entries, $result;
						$entryFound= 1;
						last;
						}
					}
					else
					{
						my $result= $self->lookupNumber($searchExpression, $userName, $base);
						if (not defined($result))
						{
						logdebug("No match found $searchExpression");
						}
						else
						{
						logdebug("answer found " . $result);
						push @entries, $result;
						$entryFound= 1;
						last;
						}
					}
					}
				}
					if ( $entryFound >= 1)
					{
						last;
					}
            }
        }
	logdebug("After first search");
        
	# Use another search round
        if ($entryFound == 0 && !$self->isSpeedDial($base))
        {
	    logdebug("2Nothing found, using second search method or->or ");
	    logdebug("2Full filter definition: " . Dumper($myFilter));
            for my $or (@{$myFilter->{'or'}}) 
            {
				logdebug("OR2 query loop");
                for my $myORCondition ($or) 
                {
                    logdebug("Found or condition: " . Dumper($myORCondition));
                    my $mySubstrings= $myORCondition->{'substrings'};
                    my $myEquality= $myORCondition->{'equalityMatch'};
                    my $myPresent= $myORCondition->{'present'};
                    
                    if (defined($myEquality))
                    {
                        if (
                            $myEquality->{'attributeDesc'} eq "telephoneNumber" ||
                            $myEquality->{'attributeDesc'} eq "mobile" ||
                            $myEquality->{'attributeDesc'} eq "homePhone" 
                        )
                        {
			    my $qNumber= $myEquality->{'assertionValue'};
			    $searchExpression= $qNumber;
			    my $result= $self->lookupNumber($qNumber, $userName, $base);
			    if (not defined($result))
			    {
				logtrace("No match found");
			    }
			    else
			    {
				logtrace("answer found " . $result);
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
			    if (!(
                                    $type eq 'telephoneNumber' ||
                                    $type eq 'mobile' ||
                                    $type eq 'homePhone' 
                                ))
			    {
				logwarn("Name0 search for $qNumber");
				@entries= $self->lookupNames($qNumber, $userName, $base, $sizeLimit);
                                if (scalar(@entries) == 0)
                                {
                                    logtrace("No match found");
                                }
                                else
                                {
                                    logtrace("answer(s) found");
                                    #push @entries, $result;
                                    $entryFound= 1;
                                    last;
                                }

			    }
			    else
			    {
				my $result= $self->lookupNumber($qNumber, $userName, $base);
				$searchExpression= $qNumber;
				if (not defined($result))
				{
				    logtrace("No match found");
				}
				else
				{
				    logtrace("answer found " . $result);
				    push @entries, $result;
				    $entryFound= 1;
				    last;
				}
			    }
                    }
                    elsif (defined($myPresent))
                    {
			    my $mySubstrings= "";
			    #my $type= $mySubstrings->{'type'};
			    #my $qNumber= $self->parseSubstring($mySubstrings);
			    #if ($type eq 'cn' || $type eq 'dn')
			    {
				@entries= $self->lookupNames("", $userName, $base, $sizeLimit);
                                if (scalar(@entries) == 0)
                                {
                                    logtrace("No match found");
                                }
                                else
                                {
                                    logtrace("answer(s) found");
                                    #push @entries, $result;
                                    $entryFound= 1;
                                    last;
                                }
			    }
			    #else
			    #{
			#	logdebug("No search mode matched $type");
			#    }
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
        
	# Use another search round
        if ($self->isSpeedDial($base))
        {
            my $myEquality= $myFilter->{'equalityMatch'};
	    logdebug("searching speedDial for " . Dumper($myEquality));

            if (defined($myEquality))
            {
                if ($myEquality->{'attributeDesc'} eq "cn" )
                {
                    my $qNumber= $speedDialPrefix . $myEquality->{'assertionValue'};
                    $searchExpression= $qNumber;
                    my $result= $self->lookupNumber($qNumber, $userName, $base);
                    if (not defined($result))
                    {
                        logtrace("No match found");
                    }
                    else
                    {
                        logdebug("answer found " . $result);
                        push @entries, $result;
                        $entryFound= 1;
                    }
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
    else
    {
        logdebug("No scope " . Dumper($base));
	if (begins_with($base, "cn=mysql_rowid_"))
	{
	    my $rowID= substr($base, 15, index($base, ','));
	    logdebug("Searching rowid $rowID");
	    @entries= $self->queryMySQLRowID($rowID, $userName, $base, 1);	    
            if (scalar(@entries) == 0)
            {
                logwarn("No match found for $base");
            }
            else
            {
                logdebug("answer found " . Dumper(@entries));
                #push @entries, $result;
                $entryFound= 1;
            }
	} 
	else
	{
            logdebug("No base with cn=mysql_rowid_ " . Dumper($base));
	}
    }
    if ($entryFound >= 1)
    {
	return RESULT_OK, @entries;
    }
    else
    {
		return RESULT_OK;
		#return RESULT_NOT_FOUND;
    }
}



sub queryTelSearch()
{
    my ($self, $qNumber, $base) = @_;
    my $retVal;
    my $originalSearchNR= $qNumber;
    my $cache = new Cache::FileCache( { 'namespace' => 'telsearch-' . $base,
                                        'default_expires_in' => $cacheTimeout } );
    if ($self->isSpeedDial($base))
    {
        return;
    }
    logdebug("Telsearch Resolve NR " . $qNumber);
    my $response= $cache->get( $qNumber );
    if (not defined ($response))
    {
        my $fullURL= $resolvURLTelsearch . $qNumber . '&key=' . $apiKeyTelsearch;
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
	    
	    my $company= $xp->find( 'tel:name', $entry )->string_value;
	    my $firstname= $xp->find( 'tel:person', $entry )->string_value;
	    my $lastname= "";
            my $address= $xp->find( 'tel:address', $entry )->string_value;
	    my $zip= $xp->find( 'tel:zip', $entry )->string_value;
	    my $city= $xp->find( 'tel:city', $entry )->string_value;
	    my $canton= $xp->find( 'tel:canton', $entry )->string_value;
            my $country= "Schweiz";
	    my $email= $xp->find( 'tel:email', $entry )->string_value;
	    my $fax= $xp->find( 'tel:fax', $entry )->string_value;
	    #my $phone = $xp->find( 'tel:phone', $entry )->string_value;
	    my $phone= $originalSearchNR;
            my $home= "";
	    logdebug("Titel: " .$title );
	    logdebug("Phone: " .$phone );
	    logdebug("Content: " .$content );
	    logdebug("Company: " .$company );
	    logdebug("FirstName: " .$firstname );
	    logdebug("LastName: " .$lastname );
	    logdebug("Address: " .$address );
	    logdebug("Zip: " .$zip );
	    logdebug("City: " .$city );
	    logdebug("Canton: " .$canton );
	    logdebug("Country: " .$country );
	    my $dnPart= "cn=telsch_".escape_dn_value($id) ;
	    my $myDN= $dnPart.",". $base;
	    my $foundEntry = Net::LDAP::Entry->new;
	    my $cn= trim($company . ' ' . $firstname) . ', ' . $zip . ' ' .$city;
	    if (defined($canton) && length($canton) > 0)
	    {
		    $cn= $cn . '/' . $canton;
	    }
	    logwarn("dn: " .$myDN );
	    logwarn("cn: " .$cn );
	    $foundEntry->dn($myDN);
	    $foundEntry->add(
#			    dn => $dnPart,
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


sub queryMySQLNumber()
{
    my ($self, $qNumber, $base) = @_;
    my $retVal;
    my $originalSearchNR= $qNumber;
    my $cache = new Cache::FileCache( { 'namespace' => 'telsearch-' . $base,
                                        'default_expires_in' => $cacheTimeout } );
    my $isSpeedDial= $self->isSpeedDial($base);
    logmsg("base= $base, isSpeedDial= $isSpeedDial");
    
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
    my $dbh = DBI->connect($dsn, $userid, $password, { mysql_enable_utf8 => 1 } ) or die $DBI::errstr;
    
    my $sql;
    if (!$self->isSpeedDial($base))
    {
        my $sth = $dbh->prepare("SELECT addressid, 
                                company, firstname, lastname, 
                                address, zip, city, country,
                                phone, mobile, home,
                                speeddial_phone, speeddial_mobile, speeddial_home,
                                fax, email
                                FROM address
                                WHERE  (phone = ? or mobile=? or home=? or speeddial_phone=? or speeddial_mobile=? or speeddial_home=?)");
        $sth->execute( $qNumber, $qNumber, $qNumber, $qNumber, $qNumber, $qNumber ) or die $DBI::errstr;
        logmsg("Number of rows found :" . $sth->rows);
        while (my @row = $sth->fetchrow_array()) {
           my ($addressid, 
           $company, $firstname, $lastname, 
           $address, $zip, $city, $country,
           $phone, $mobile, $home,
           $speeddial_phone, $speeddial_mobile, $speeddial_home,
           $fax, $email) = @row;

           my $finalNr= $qNumber;
           my $prefix= "";
           if (defined($speeddial_phone) && $speeddial_phone == $qNumber)
           {
               $finalNr= $phone;
               $prefix= "KW T:";
           }
           if (defined($speeddial_mobile) && $speeddial_mobile == $qNumber)
           {
               $finalNr= $mobile;
               $prefix= "KW M:";
           }
            my $dnPart= "cn=mysql_".escape_dn_value($addressid.$finalNr);
            my $myDN= $dnPart .",". $base;
            my $foundEntry = Net::LDAP::Entry->new;
            my $cn= $prefix . $self->makeDisplayName($base, $company, $firstname, $lastname);
            logwarn("dn: " .$myDN );
            logwarn("cn: " .$cn );
            $foundEntry->dn($myDN);
            $foundEntry->add(
                            cn => $cn);
	    $self->addResultProperties($foundEntry, $base, $finalNr,
            $company, $firstname, $lastname, 
            $address, $zip, $city, $country,
           $phone, $mobile, $home,
           $speeddial_phone, $speeddial_mobile, $speeddial_home,
            $fax, $email
            );
            $retVal= $foundEntry;
        }
        $sth->finish();
    }
    else
    {
        # Query speeddial
        my $sth1 = $dbh->prepare("SELECT addressid, 
                                company, firstname, lastname, 
                                address, zip, city, country,
                                phone, mobile, home,
                                speeddial_phone, speeddial_mobile, speeddial_home,
                                fax, email
                                FROM address
                                WHERE speeddial_phone = ?");
        $sth1->execute(  $qNumber ) or die $DBI::errstr;
        logmsg("Number of rows found :" . $sth1->rows);
        if ($sth1->rows > 0)
        {
            while (my @row = $sth1->fetchrow_array()) {
            my ($addressid, 
            $company, $firstname, $lastname, 
            $address, $zip, $city, $country,
           $phone, $mobile, $home,
           $speeddial_phone, $speeddial_mobile, $speeddial_home,
            $fax, $email) = @row;

                my $dnPart= "cn=mysql_sdp".escape_dn_value($addressid);
                my $myDN= $dnPart .",". $base;
                my $foundEntry = Net::LDAP::Entry->new;
                logwarn("dn: " .$myDN );
                $foundEntry->dn($myDN);
                $foundEntry->add(
#                                dn => $dnPart,
                                cn => $self->makeDisplayName($base, $company, $firstname, $lastname),
                                );
		$self->addResultProperties($foundEntry, $base, $phone,
                    $company, $firstname, $lastname, 
                    $address, $zip, $city, $country,
                    $phone, $mobile, $home,
                    $speeddial_phone, $speeddial_mobile, $speeddial_home,
                    $fax, $email);
                $retVal= $foundEntry;
            }
        } 
        else
        {
            my $sth2 = $dbh->prepare("SELECT addressid, 
                                    company, firstname, lastname, 
                                    address, zip, city, country,
                                phone, mobile, home,
                                speeddial_phone, speeddial_mobile, speeddial_home,
                                    fax, email
                                    WHERE  speeddial_mobile = ?");
            $sth2->execute(  $qNumber ) or die $DBI::errstr;
            logmsg("Number of rows found :" . $sth2->rows);
            if ($sth2->rows > 0)
            {
                while (my @row = $sth2->fetchrow_array()) {
                    my ($addressid, 
                    $company, $firstname, $lastname, 
                    $address, $zip, $city, $country,
           $phone, $mobile, $home,
           $speeddial_phone, $speeddial_mobile, $speeddial_home,
                    $fax, $email) = @row;
                   #logdebug("Searchresult SpeeddialMobil: id= $addressid, mobile= $mobile company= $company firstname= $firstname email= $email");

                    my $dnPart= "cn=mysql_sdp".escape_dn_value($addressid);
                    my $myDN= $dnPart .",". $base;
                    my $foundEntry = Net::LDAP::Entry->new;
                    logwarn("dn: " .$myDN );
                    $foundEntry->dn($myDN);
                    $foundEntry->add(
#                                    dn => $dnPart,
                                    cn => $self->makeDisplayName($base, $company, $firstname, $lastname)
				    );
		    $self->addResultProperties($foundEntry, $base, $mobile,
                        $company, $firstname, $lastname, 
                        $address, $zip, $city, $country,
           $phone, $mobile, $home,
           $speeddial_phone, $speeddial_mobile, $speeddial_home,
                        $fax, $email
                    );
                    $retVal= $foundEntry;
                }
            }
            else
            {
                my $sth3 = $dbh->prepare("SELECT addressid, 
                                        company, firstname, lastname, 
                                        address, zip, city, country,
                                    phone, mobile, home,
                                    speeddial_phone, speeddial_mobile, speeddial_home,
                                        fax, email
                                        WHERE  speeddial_home= ?");
                $sth3->execute(  $qNumber ) or die $DBI::errstr;
                logmsg("Number of rows found :" . $sth3->rows);
                if ($sth3->rows > 0)
                {
                    while (my @row = $sth3->fetchrow_array()) {
                        my ($addressid, 
                        $company, $firstname, $lastname, 
                        $address, $zip, $city, $country,
               $phone, $mobile, $home,
               $speeddial_phone, $speeddial_mobile, $speeddial_home,
                        $fax, $email) = @row;
                       #logdebug("Searchresult SpeeddialMobil: id= $addressid, mobile= $mobile company= $company firstname= $firstname email= $email");

                        my $dnPart= "cn=mysql_sdp".escape_dn_value($addressid);
                        my $myDN= $dnPart .",". $base;
                        my $foundEntry = Net::LDAP::Entry->new;
                        logwarn("dn: " .$myDN );
                        $foundEntry->dn($myDN);
                        $foundEntry->add(
    #                                    dn => $dnPart,
                                        cn => $self->makeDisplayName($base, $company, $firstname, $lastname)
                                        );
                        $self->addResultProperties($foundEntry, $base, $mobile,
                            $company, $firstname, $lastname, 
                            $address, $zip, $city, $country,
               $phone, $mobile, $home,
               $speeddial_phone, $speeddial_mobile, $speeddial_home,
                            $fax, $email
                        );
                        $retVal= $foundEntry;
                    }
                }
                $sth3->finish();
            }
            $sth2->finish();
        }
        $sth1->finish();
    }
    
    if (not defined($retVal))
    {
	logwarn("SearchMySQL not found: ".$qNumber);
    }
    else
    {
	logdebug("SearchMySQL found: ".$retVal);
    }
    
    return $retVal;
}

sub queryMySQLNames()
{
    my ($self, $qName, $base, $sizeLimit) = @_;
    my $retVal;
    my @entries;
    
    my $cache = new Cache::FileCache( { 'namespace' => 'telsearch-' . $base,
                                        'default_expires_in' => $cacheTimeout } );
    
    logdebug("MySQL Resolve name <" . $qName .">");
    my $dbh = DBI->connect($dsn, $userid, $password, { mysql_enable_utf8 => 1 } ) or die $DBI::errstr;
    my $searchExpression= $qName."%";
    my $sql;
    my $sth = $dbh->prepare("SELECT addressid, 
                                company, firstname, lastname, 
                                address, zip, city, country,
                                phone, mobile, home,
                                speeddial_phone, speeddial_mobile, speeddial_home,
                                fax, email
                            FROM address
                            WHERE (firstname like ? or lastname like ? or company like ?)
                            LIMIT $sizeLimit
                            ");
    $sth->execute(  $searchExpression, $searchExpression, $searchExpression) or die $DBI::errstr;
    logmsg("Number of rows found :" . $sth->rows);
    while (my @row = $sth->fetchrow_array()) {
        my ($addressid, 
        $company, $firstname, $lastname, 
        $address, $zip, $city, $country,
           $phone, $mobile, $home,
           $speeddial_phone, $speeddial_mobile, $speeddial_home,
        $fax, $email
        ) = @row;

        my $dnPart= "cn=mysql_rowid_".escape_dn_value($addressid);
        my $myDN= $dnPart .",". $base;
        my $foundEntry = Net::LDAP::Entry->new;
        my $cn= $self->makeDisplayName($base,  $company , $firstname, $lastname);
        logdebug("dn: " .$myDN );
        logdebug("cn: " .$cn );
        $foundEntry->dn($myDN);
        $foundEntry->add(
#                        dn => $dnPart,
                        cn => $cn);
	$self->addResultProperties($foundEntry, $base, $phone, 
            $company, $firstname, $lastname, 
            $address, $zip, $city, $country,
           $phone, $mobile, $home,
           $speeddial_phone, $speeddial_mobile, $speeddial_home,
            $fax, $email
        );
        push @entries, $foundEntry;
        if (scalar(@entries) >= $sizeLimit)
        {
            logdebug("SearchMySQLNames requested $sizeLimit entries found");
            last;
        }
    }
    $sth->finish();
    if (scalar(@entries) == 0)
    {
	logwarn("SearchMySQLNames not found: ".$qName);
    }
    else
    {
	logdebug("SearchMySQLNames found: ". Dumper(@entries));
    }
    return @entries;
}

sub queryMySQLRowID()
{
    my ($self, $rowID, $userID, $base, $sizeLimit) = @_;
    my $retVal;
    my @entries;
    
    my $cache = new Cache::FileCache( { 'namespace' => 'telsearch-' . $base,
                                        'default_expires_in' => $cacheTimeout } );
    
    logdebug("MySQL Resolve rowid " . $rowID);
    my $dbh = DBI->connect($dsn, $userid, $password, { mysql_enable_utf8 => 1 } ) or die $DBI::errstr;
    #my $searchExpression= "%".$qName."%";
    my $sql;
    my $sth = $dbh->prepare("SELECT addressid, 
                                company, firstname, lastname, 
                                address, zip, city, country,
                                phone, mobile, home,
                                speeddial_phone, speeddial_mobile, speeddial_home,
                                fax, email
                            FROM address
                            WHERE  addressid=?");
    $sth->execute(  $rowID ) or die $DBI::errstr;
    logmsg("Number of rows found :" . $sth->rows);
    while (my @row = $sth->fetchrow_array()) {
        my ($addressid, 
        $company, $firstname, $lastname, 
        $address, $zip, $city, $country,
           $phone, $mobile, $home,
           $speeddial_phone, $speeddial_mobile, $speeddial_home,
        $fax, $email
        ) = @row;

        #my $dnPart= "cn=mysql_rowid_".$addressid;
        my $myDN= $base;
        my $foundEntry = Net::LDAP::Entry->new;
        my $cn= $self->makeDisplayName( $base, $company , $firstname, $lastname);
        logdebug("dn: " .$myDN );
        logdebug("cn: " .$cn );
        $foundEntry->dn($myDN);
        $foundEntry->add(
#                        dn => $base,
                        cn => $cn);
	$self->addResultProperties($foundEntry, $base, $phone,
            $company, $firstname, $lastname, 
            $address, $zip, $city, $country,
           $phone, $mobile, $home,
           $speeddial_phone, $speeddial_mobile, $speeddial_home,
            $fax, $email
        );
        push @entries, $foundEntry;
        if (scalar(@entries) >= $sizeLimit)
        {
            logdebug("SearchMySQLNames requested $sizeLimit entries found");
            last;
        }
    }
    $sth->finish();
    if (scalar(@entries) == 0)
    {
	logwarn("SearchMySQLRowID not found: ".$rowID);
    }
    else
    {
	logdebug("SearchMySQLNames found: ". Dumper(@entries));
    }
    return @entries;
}

sub lookupNumber()
{
    my ($self, $qNumber, $userName, $base) = @_;
    my $isSpeedDial= $self->isSpeedDial($base);
    
    my $retVal;
    my $entryFound= 0;
    
    logwarn("Lookup number $qNumber for $userName in context $base");
    
    if ($useDBSearch == 1 )
	{
		logdebug("Query MySQL for $qNumber");
		my $answer= $self->queryMySQLNumber($qNumber, $base);
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

    if ($useTelSearch == 1 && !$isSpeedDial)
	{
		if ($entryFound == 0 && index($qNumber, '+41') == 0 && length($qNumber) > 10 && length($qNumber) < 14 )
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

sub lookupNames()
{
    my ($self, $qName, $userName, $base, $sizeLimit) = @_;
    my $retVal;
    my $entryFound= 0;
    my @entries;
    
    logwarn("Lookup name $qName for $userName in context $base, maxAnswers <$sizeLimit>");
    
    if ($useDBSearch == 1 )
	{
            logdebug("Query MySQL for $qName");
            @entries= $self->queryMySQLNames($qName, $base, $sizeLimit);
	}

    return @entries;
}

sub parseSubstring()
{
    my ($self, $substringQuery) = @_;
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

sub makeDisplayName()
{
    my ($self, $base, $company, $firstname, $lastname) = @_;


    my $displayName= "";
    if (defined($lastname) && length($lastname) > 0)
    {
            $displayName= $lastname;
    }
    if (defined($firstname) && length($firstname) > 0)
    {
        if (length($displayName) > 0)
        {
            $displayName= $displayName . ', ' . $firstname;
        }
        else
        {
            $displayName= $firstname;
        }
    }
    if (defined($company) && length($company) > 0)
    {
        if (length($displayName) > 0)
        {
            $displayName= $displayName . ', ' . $company;
        }
        else
        {
            $displayName= $company;
        }
    }
    if (length($displayName) == 0)
    {
	$displayName= "Error, no name found";
	logerr("Company and Name all undefined or empty");
    }

    if ($self->isGigaset($base))
    {
	return $self->removeUmlauts($displayName);
    }
    else
    {
	return $displayName;
    }
}

sub addResultProperties()
{
    my ($self, $foundEntry, $dn, $base, 
        $company, $firstname, $lastname, 
        $address, $zip, $city, $country,
        $phone, $mobile, $home,
        $speeddial_phone, $speeddial_mobile, $speeddial_home,
        $fax, $email
        ) = @_;
    # Order of attributes is relevant
    
    if ($self->isGigaset($base))
    {
		if (defined($company) && length($company) > 0 ) { $foundEntry->add(company => $self->removeUmlauts($company)); }
		if (defined($firstname) && length($firstname) > 0 ) { $foundEntry->add(sn => $self->removeUmlauts($firstname)); }
		if (defined($lastname) && length($lastname) > 0 ) { $foundEntry->add(givenName => $self->removeUmlauts($lastname)); }
		if (defined($address) && length($address) > 0 ) { $foundEntry->add(postalAddress => $self->removeUmlauts($address)); }
		if (defined($zip) && length($zip) > 0 ) { $foundEntry->add(postalCode => $self->removeUmlauts($zip)); }
		if (defined($city) && length($city) > 0 ) { $foundEntry->add(l => $self->removeUmlauts($city)); }
		if (defined($country) && length($country) > 0 ) { $foundEntry->add(countryCode => $self->removeUmlauts($country)); }
        if (defined($email) && length($email) > 0 ) { $foundEntry->add(mail => $self->removeUmlauts($email)); }
    }
    else
    {
		if (defined($company) && length($company) > 0 ) { $foundEntry->add(company => $company); }
		if (defined($firstname) && length($firstname) > 0 ) { $foundEntry->add(sn => $firstname); }
		if (defined($lastname) && length($lastname) > 0 ) { $foundEntry->add(givenName => $lastname); }
		if (defined($address) && length($address) > 0 ) { $foundEntry->add(postalAddress => $address); }
		if (defined($zip) && length($zip) > 0 ) { $foundEntry->add(postalCode => $zip); }
		if (defined($city) && length($city) > 0 ) { $foundEntry->add(l => $city); }
		if (defined($country) && length($country) > 0 ) { $foundEntry->add(countryCode => $country); }
        if (defined($email) && length($email) > 0 ) { $foundEntry->add(mail => $email); }
    }
    if (defined($phone) && length($phone) > 0 ) { $foundEntry->add(telephoneNumber => $self->makeResultNumber($base, $phone)); }
    if (defined($mobile) && length($mobile) > 0 ) { $foundEntry->add(mobile => $self->makeResultNumber($base, $mobile))}; 
    if (defined($home) && length($home) > 0 ) { $foundEntry->add(homePhone => $self->makeResultNumber($base, $home))}; 
    if (defined($fax) && length($fax) > 0 ) { $foundEntry->add(facsimileTelephoneNumber => $self->makeResultNumber($base, $fax))}; 
    if (defined($speeddial_phone) && length($speeddial_phone) > 0 ) { $foundEntry->add(speedDial => $speeddial_phone); }
    if (defined($speeddial_mobile) && length($speeddial_mobile) > 0 ) { $foundEntry->add(speedDialMobile => $speeddial_mobile); }
    if (defined($speeddial_home) && length($speeddial_home) > 0 ) { $foundEntry->add(speedDialHome => $speeddial_home); }
}

# When gigaset solution, expand + to international prefix
sub makeResultNumber()
{
    my ($self, $base, $number) = @_;
    if (begins_with($number, '+') && $self->isGigaset($base))
    {
	logtrace('Adding number '.$number.' as gigaset to results');
	return  $gigasetInternationalPrefix . substr($number, 1);
    }
    else
    {
	logtrace('Adding number '.$number.' as normal number to results');
	return $number;
    }
}


# When we have a speeddial in the DN, then this is a query for speeddial stuff
sub isSpeedDial
{
    my ($self, $base) = @_;
    return $base =~ m/speeddial/;
}
# When we have a gigaset the DN, then we expand the + to the international prefix
sub isGigaset
{
    my ($self, $base) = @_;
    return $base =~ m/gigaset/;
}

sub logmsg {
  print STDERR (scalar localtime() . " @_\n");
}

sub logwarn {
  warn scalar localtime() . " @_\n";
}

sub logerr {
  print STDERR (scalar localtime() . ":ERROR: @_\n");
}

sub loginfo {
  print STDERR (scalar localtime() . ":INFO: @_\n");
}

sub logdebug {
  if ($debug) {
    print STDERR (scalar localtime() . ":DEBUG: @_\n");
  }
}

sub logtrace {
  if ($logTrace) {
    print STDERR (scalar localtime() . ":TRACE: @_\n");
  }
}

sub begins_with
{
    my $retVal= substr($_[0], 0, length($_[1])) eq $_[1];
    logtrace("Begins with <$_[0]> search for <$_[1]> return $retVal");
    return $retVal;
}

sub  trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s };


sub removeUmlauts
{
    my ($self, $inString) = @_;
	if ($gigasetRemoveUmlauts)
	{
		my %umlaute = ("ä" => "ae", "Ä" => "Ae", "ü" => "ue", "Ü" => "Ue", "ö" => "oe", "Ö" => "Oe", "ß" => "ss", "é" => "e" );
		my $umlautkeys = join ("|", keys(%umlaute));
		$inString =~ s/($umlautkeys)/$umlaute{$1}/g;
		logdebug("String after map umlauts " . $inString);
		return $inString;
	}
	else
	{
		return $inString;
	}
}


# the rest of the operations will return an "unwilling to perform"

1;
