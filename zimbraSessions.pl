#!/usr/bin/perl

use strict;
use Getopt::Long;
use XML::Simple;
use Data::Dumper;

my $warning;
my $critical;
my $zimbraUser;

my $defaultWarning = 80;
my $defaultCritical = 90;
my $defaultZimbraUser = 'zimbra';

my $zmprov = '/opt/zimbra/bin/zmprov';
my $zmhostname = '/opt/zimbra/bin/zmhostname';
my $zmsoap = '/opt/zimbra/bin/zmsoap';

my $username = (getpwuid $>);

GetOptions (    "zimbra-user=s" =>      \$zimbraUser,
                "warning=s"     =>      \$warning,
                "critical=s"    =>      \$critical);

if (!defined($warning)) {
        $warning = $defaultWarning;
}

if (!defined($critical)) {
        $critical = $defaultCritical;
}

if (!defined($zimbraUser)) {
        $zimbraUser = $defaultZimbraUser;
}

if ( $warning > $critical) {
        print "critical value must be greater than warning valuei\n";
        exit(2);
}

if (!-f $zmprov) {
        print "file $zmprov does not exists\n";
        exit(2);
}

if ( $warning > 100 || $critical > 100 ) {
        print "warning and critical values must be less than 100\n";
        exit(2);
}

if (!getpwnam($zimbraUser)) {
        print "User $zimbraUser does not exists\n";
}

if ($username ne $zimbraUser) {
        print "script must be started with user $zimbraUser\n";
        exit(2);
}

if (!-f $zmprov) {
        print "file $zmprov not found";
        exit(2);
}

if (!-f $zmhostname) {
        print "file $zmhostname not found";
        exit(2);
}

if (!-f $zmsoap) {
        print "file $zmsoap not found";
        exit(2);
}

my $maxImapSessions = getImapMaxConnections();
my %hashSessions = getCurrentSessions();
my $persentActiveSessions = ($hashSessions{imapActiveSessions} / $maxImapSessions) * 100;

if ( $persentActiveSessions < $warning ) {
        print "OK active imap sessions $hashSessions{imapActiveSessions} | activeSessions=$hashSessions{imapActiveSessions}\n";
        exit(0);
} elsif ($persentActiveSessions > $warning && $persentActiveSessions < $critical ) {
        print "WARNING active imap sessions $hashSessions{imapActiveSessions} | activeSessions=$hashSessions{imapActiveSessions}\n";
        exit(1);
} else {
        print "CRITICAL active imap sessions $hashSessions{imapActiveSessions} | activeSessions= $hashSessions{imapActiveSessions}\n";
        exit(2);
}

############################################

sub getImapMaxConnections {

my $serverName = `$zmhostname`;
my $imapMaxConnections;
chomp $serverName;

my $imapCommand = "$zmprov gs $serverName zimbraImapMaxConnections";
my @output = `$imapCommand`;
foreach my $line (@output) {
        chomp $line;
        next if $line !~ /zimbraImapMaxConnections/;
        if ($line =~ /zimbraImapMaxConnections\:\s+(\d+)/){
                $imapMaxConnections = $1;
        }
}
return $imapMaxConnections;
}

sub getCurrentSessions {

my $sessions = `$zmsoap -z -t admin DumpSessionsRequest`;
my $xml = new XML::Simple;
my $data = $xml->XMLin($sessions);
my %sessions;

#print Dumper($data);

my $activeSessions = $data -> {activeSessions};
my $imapActiveAccounts = $data -> {imap} -> {activeAccounts};
my $imapActiveSessions = $data -> {imap} -> {activeSessions};

$sessions{imapActiveAccounts} = $data -> {imap} -> {activeAccounts};
$sessions{imapActiveSessions} = $data -> {imap} -> {activeSessions};
$sessions{adminActiveAccounts} = $data -> {admin} -> {activeAccounts};
$sessions{adminActiveSessions} = $data -> {admin} -> {activeSessions};
$sessions{soapActiveAccounts} = $data -> {soap} -> {activeAccounts};
$sessions{soapActiveSessions} = $data -> {soap} -> {activeSessions};

return %sessions;

}
