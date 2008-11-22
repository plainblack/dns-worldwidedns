package DNS::WorldWideDns;

BEGIN {
    use vars qw($VERSION);
    $VERSION     = '0.01';
}


use strict;
use Class::InsideOut qw(readonly private id register);
use Exception::Class (
        'Exception' => {
            description => 'A general error.',
        },

        'MissingParam' => {
            isa         => 'Exception',
            description => 'Expected a parameter that was not specified.',
        },

        'InvalidParam' => {
            isa         => 'Exception',
            description => 'A parameter passed in did not match what it was supposed to be.',
            fields      => [qw(got)],
        },

        'InvalidAccount' => {
            isa         => 'RequestError',
            description => 'Authentication failed.',
        },

        'RequestError' => {
            isa         => 'Exception',
            description => 'Something bad happened during the request.',
            fields      => [qw(url response code)],
        },

    );
use HTTP::Request;
use LWP::UserAgent;

readonly username => my %username;
readonly password => my %password;



=head1 NAME

DNS::WorldWideDns - An interface to the worldwidedns.net service.

=head1 SYNOPSIS

 use DNS::WorldWideDns;

 $dns = DNS::WorldWideDns->new($user, $pass);

=head1 DESCRIPTION

This module allows you to dynamically create, remove, update, delete, and report on domains hosted at worldwidedns.net.

=head1 USAGE

The following methods are available from this class:

=cut


###############################################################

=head2 addDomain ( domain, [ isPrimary, isDynamic ] )

Adds a domain to your account. Throws MissingParam, InvalidParam, InvalidAccount and RequestError.

Returns a 1 on success.

=head3 domain

A domain to add.

=head3 isPrimary

A boolean indicating if this is a primary domain, or a slave. Defaults to 1.

=head3 isDynamic

A boolean indicating whether this domain is to allow Dynamic DNS ip updating. Defaults to 0.

=cut

sub addDomain {
    my ($self, $domain, $isPrimary, $isDynamic) = @_;
	unless (defined $domain) {
        MissingParam->throw(error=>'Need a domain.');
    }
	unless ($domain =~ m{^[\w\-\.]+$}xms) {
        InvalidParam->throw(error=>'Domain is improperly formatted.', got=>$domain);
    }
    my $primary = ($isPrimary eq "" || $isPrimary == 1) ? 0 : 1;
    my $dynamic = ($isDynamic eq "" || $isDynamic == 0) ? 1 : 2;
    my $url = 'https://www.worldwidedns.net/api_dns_new_domain.asp?NAME='.$self->username.'&PASSWORD='.$self->password.'&DOMAIN='.$domain.'&DYN='.$dynamic.'&TYPE='.$primary;
    my $response =  $self->makeRequest($url);
    my $content = $response->content;
    chomp $content;
    if ($content eq "200") {
        return 1;
    }
    elsif ($content eq "407") {
        RequestError->throw(
            error       => 'Account domain limit exceeded.',
            url         => $url,
            code        => $content,
            response    => $response,
        );     
    }
    elsif ($content eq "408") {
        RequestError->throw(
            error       => 'Domain already exists.',
            url         => $url,
            code        => $content,
            response    => $response,
        );     
    }
    elsif ($content eq "409") {
        RequestError->throw(
            error       => 'Domain banned by DNSBL.',
            url         => $url,
            code        => $content,
            response    => $response,
        );     
    }
    elsif ($content eq "410") {
        RequestError->throw(
            error       => 'Invalid domain name.',
            url         => $url,
            code        => $content,
            response    => $response,
        );     
    }
    RequestError->throw(
        error       => 'Got back an invalid response.',
        url         => $url,
        response    => $response,
    );     
}



###############################################################

=head2 getDomain ( domain )

Retrieves the information about a domain. Throws MissingParam, InvalidParam, InvalidAccount and RequestError.

Returns a hash reference structure that looks like this:

 {
    hostmaster  => "you.example.com",
    refresh     => "86400",
    retry       => "1200",
    expire      => "186400",
    ttl         => "3600",
    transferAcl => "*",
    records     => [
        {
            name    => "smtp",
            type    => "A",
            data    => "1.1.1.1"
        },
        {
            name    => "@",
            type    => "MX",
            data    => "10 smtp.example.com"
        },
    ]
 }
 
The transferAcl parameter is an access control list for zone transfers. Asterisk (*) implies that anyone can do zone transfers. Otherwise it could be a list of IP addresses separated by spaces.

This method will return a maximum of twenty records in the record field.

=head3 domain

A domain to request information about.

=cut

sub getDomain {
    my ($self, $domain) = @_;
	unless (defined $domain) {
        MissingParam->throw(error=>'Need a domain.');
    }
	unless ($domain =~ m{^[\w\-\.]+$}xms) {
        InvalidParam->throw(error=>'Domain is improperly formatted.', got=>$domain);
    }
    my $url = 'https://www.worldwidedns.net/api_dns_list_domain.asp?NAME='.$self->username.'&PASSWORD='.$self->password.'&DOMAIN='.$domain;
    my $response =  $self->makeRequest($url);
    my $content = $response->content;
    chomp $content;
    if ($content eq "405") {
        RequestError->throw(
            error       => 'Domain name could not be found.',
            url         => $url,
            code        => 405,
            response    => $response,
        );     
    }
    my @lines = split "\n", $response->content;
    my %domain;
    $domain{hostmaster} = shift @lines;
    $domain{refresh} = shift @lines;
    $domain{retry} = shift @lines;
    $domain{expire} = shift @lines;
    $domain{ttl} = shift @lines;
    $domain{secure} = shift @lines;
    foreach my $line (@lines) {
        $line =~ m{^([\w\-\.\*\@]+)\x1F(A|A6|AAAA|AFSDB|CNAME|DNAME|HINFO|ISDN|MB|MG|MINFO|MR|MX|NS|NSAP|PTR|RP|RT|SOA|SRV|TXT|X25)\x1F(.+)$}xmsi;
        my $name = $1;
        my $type = $2;
        my $recordData = $3;
        print join('~',$name,$type,$recordData);
        chomp $recordData;
#        push @{$domain{records}}, {
 #           name    => $name,
  #          type    => $type,
   #         data    => $recordData,
    #        };
    }
    return \%domain;
}


###############################################################

=head2 getZone ( domain, [ nameServer ] )

Retrieves the zone file for a domain from a specific name server. Throws MissingParam, InvalidParam, InvalidAccount and RequestError.

Returns a zone file.

=head3 domain

A domain to request information about.

=head3 nameServer

Defaults to 1. Choose from 1, 2, or 3. The number of the primary, secondary or tertiary name server.

=cut

sub getZone {
    my ($self, $domain, $nameServer) = @_;
	unless (defined $domain) {
        MissingParam->throw(error=>'Need a domain.');
    }
	unless ($domain =~ m{^[\w\-\.]+$}xms) {
        InvalidParam->throw(error=>'Domain is improperly formatted.', got=>$domain);
    }
    $nameServer ||= 1;
    my $url = 'https://www.worldwidedns.net/api_dns_list_domain.asp?NAME='.$self->username.'&PASSWORD='.$self->password.'&DOMAIN='.$domain.'&NS='.$nameServer;
    my $response =  $self->makeRequest($url);
    my $content = $response->content;
    chomp $content;
    if ($content eq "405") {
        RequestError->throw(
            error       => 'Domain name could not be found.',
            url         => $url,
            code        => 405,
            response    => $response,
        );     
    }
    elsif ($content eq "450") {
        RequestError->throw(
            error       => 'Could not reach the name server.',
            url         => $url,
            code        => 450,
            response    => $response,
        );     
    }
    elsif ($content eq "451") {
        RequestError->throw(
            error       => 'No zone file for this domain on this name server.',
            url         => $url,
            code        => 451,
            response    => $response,
        );     
    }
    return $content;
}


###############################################################

=head2 getDomains ( )

Returns a hash reference where the key is the domain and the value is either a 'Primary' or an 'Slave'. Throws InvalidAccount and RequestError.

=cut

sub getDomains {
    my $self = shift;
    my $url = 'https://www.worldwidedns.net/api_dns_list.asp?NAME='.$self->username.'&PASSWORD='.$self->password;
    my $content = $self->makeRequest($url)->content; 
    my %domains;
    while ($content =~ m{([\w+\.\-]+)\x1F(P|S)}xmsig) {
        print $1."\n";
        my $type = ($2 eq 'P') ? 'Primary' : 'Secondary';
        $domains{$1} = $type;
    }
    return \%domains;
}


###############################################################

=head2 makeRequest ( url )

Makes a GET request. Returns the HTTP::Response from the request. Throws MissingParam, InvalidParam, InvalidAccount and RequestError.

B<NOTE:> Normally you never need to use this method, it's used by the other methods in this class. However, it may be useful in subclassing this module.

=head3 url

The URL to request.

=cut

sub makeRequest {
    my ($self, $url) = @_;
	unless (defined $url) {
        MissingParam->throw(error=>'Need a url.');
    }
	unless ($url =~ m{^https://www.worldwidedns.net/.*$}xms) {
        InvalidParam->throw(error=>'URL is improperly formatted.', got=>$url);
    }
    my $request =  HTTP::Request->new(GET => $url);
    my $ua = LWP::UserAgent->new;
    my $response = $ua->request($request);
    
    # request is good
    if ($response->is_success) {
        my $content = $response->content;
        chomp $content;
        
        # is our account still active
        if ($content eq "401") {
            InvalidAccount->throw(
                error       => 'Login suspended.',
                url         => $url,
                code        => 401,
                response    => $response,
            );
        }
        
        # is our user/pass good
        elsif ($content eq "403") {
            InvalidAccount->throw(
                error       => 'Invalid user/pass combination.',
                url         => $url,
                code        => 403,
                response    => $response,
            );
        }
        
        # we're good, let's get back to work
        return $response;
    }
    
    # the request went totally off the reservation
    RequestError->throw(
        error       => $response->message,
        url         => $url,
        response    => $response,
    );

}

###############################################################

=head2 new ( username, password )

Constructor.

 Usage     : $dns = DNS::WorldWideDns->new($username, $password);
 Argument  :
    username    : Your worldwidedns.net username.
    password    : The password to go with username.
 Throws    : MissingParam

=cut

sub new {
    my ($class, $username, $password) = @_;

	# validate
	unless (defined $username) {
        MissingParam->throw(error=>'Need a username.');
    }
    unless (defined $password) {
        MissingParam->throw(error=>'Need a password.');
    }

	# set up object
	my $self = register($class);
	my $refId = id $self;
	$username{$refId} = $username;
	$password{$refId} = $password;
	return $self;
}

###############################################################

=head2 password ()

Returns the password set in the constructor.

 Usage     : $dns->password;
 Argument  :
 Throws    : 

=cut

###############################################################

=head2 updateDomain ( domain, params )

Updates a domain in your account. Throws MissingParam, InvalidParam, InvalidAccount and RequestError.

Returns a 1 on success.

=head3 domain

A domain to update.

=head3 params

A hash reference identical to the one returned by getDomain().

=cut

sub updateDomain {
    my ($self, $domain, $params) = @_;
    
    # validate inputs
	unless (defined $domain) {
        MissingParam->throw(error=>'Need a domain.');
    }
	unless ($domain =~ m{^[\w\-\.]+$}xms) {
        InvalidParam->throw(error=>'Domain is improperly formatted.', got=>$domain);
    }
	unless (defined $params) {
        MissingParam->throw(error=>'Need parameters hash ref to set on the domain.');
    }
	unless (ref $params eq 'HASH') {
        InvalidParam->throw(error=>'Expected a params hash reference.', got=>$params);
    }

    # make request
    my $url = 'https://www.worldwidedns.net/api_dns_modify.asp?NAME='.$self->username.'&PASSWORD='.$self->password.'&DOMAIN='.$domain
        .'&HOSTMASTER='.$params->{hostmaster}
        .'&REFRESH='.$params->{refresh}
        .'&RETRY='.$params->{retry}
        .'&SECURE='.$params->{transferAcl}
        .'&EXPIRE='.$params->{exipre}
        .'&TTL='.$params->{ttl};
    my $i=1;
    foreach my $record (@{$params->{records}}) {
        $url .= '&S'.$i.'='.$record->{name}
            .'&T'.$i.'='.$record->{type}
            .'&D'.$i.'='.$record->{data};
        $i++;
    }        
    my $response =  $self->makeRequest($url);
    my $content = $response->content;
    chomp $content;
    
    # interpret results
    if ($content =~ m{211\s*212\s*213}xmsi) {
        return 1;
    }
    elsif ($content eq "405") {
        RequestError->throw(
            error       => 'Domain not in account.',
            url         => $url,
            code        => $content,
            response    => $response,
        );     
    }
    RequestError->throw(
        error       => 'Updating one of the name servers failed.',
        url         => $url,
        code        => $content,
        response    => $response,
    );     
}

###############################################################

=head2 username ()

Returns the username set in the constructor.

 Usage     : $dns->username;
 Argument  :
 Throws    : 

=cut


=head1 EXCEPTIONS



=head1 BUGS



=head1 SUPPORT



=head1 AUTHOR

    JT Smith
    CPAN ID: RIZEN
    Plain Black Corporation
    jt_at_plainblack_com
    http://www.plainblack.com/

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

1;
# The preceding line will help the module return a true value

