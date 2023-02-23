#!/usr/bin/perl
# Copyright (c) 2023 Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.
use Mail::IMAPClient;
use strict;
my $user  = shift;
my $quota = shift || -1;

my $passwd=`grep de.cranix.dao.User.Register.Password= /opt/cranix-java/conf/cranix-api.properties | /usr/bin/sed 's/de.cranix.dao.User.Register.Password=//'`;
chomp $passwd;
my $imap = Mail::IMAPClient->new(
  Server   => 'localhost',
  User     => 'register',
  Password => $passwd,
  Ssl      => 0,
  Uid      => 1,
);
if( $quota == 0 ){
	$quota = -1;
}
$imap->setquota("user".$imap->separator.$user,"STORAGE",$quota);
print $imap->quota("user".$imap->separator.$user)."\n";
print $imap->quota_usage("user".$imap->separator.$user)."\n";

