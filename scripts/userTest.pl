use lib '../lib';
use strict;
use DNS::WorldWideDns;
use Exception::Class;
use Getopt::Long;
use Data::Dumper;


# Can't make these regular tests because they require a login to function.


GetOptions(
    'username=s' => \my $username,
    'password=s' => \my $password,
);


if ($username eq "" || $password eq "") {
    print "Usage: perl userTest.pl --username=myuser --password=mypass\n";
    exit;
}

print "Creating DNS object.\n";
my $dns = DNS::WorldWideDns->new($username,$password);

print "Add a domain.\n";
eval { $dns->addDomain("myexampledomain.org") };
if (my $e = Exception::Class->caught) {
    print $e->url."\n";
    print $e->code."\n";
    print $e->error."\n";
}
else {
    print "Success\n";
}

print "Getting the domain list.\n";
my $domains = eval{$dns->getDomains};
if (my $e = Exception::Class->caught) {
    print $e->url."\n";
    print $e->code."\n";
    print $e->error."\n";
}
else {
    print Dumper($domains)."\n";
}

print "Getting a specific domain.\n";
my $domain = eval {$dns->getDomain('myexampledomain.org')};
if (my $e = Exception::Class->caught) {
    print $e->url."\n";
    print $e->code."\n";
    print $e->error."\n";
}
else {
    print Dumper($domain)."\n";
}

print "Getting a specific zone file.\n";
my $zone = eval {$dns->getZone('myexampledomain.org')};
if (my $e = Exception::Class->caught) {
    print $e->url."\n";
    print $e->code."\n";
    print $e->error."\n";
}
else {
    print $zone."\n";
}

