package Net::Amazon::Signature;

use 5.10.0;
use strict;
use warnings;

use Digest::SHA qw/sha256_hex hmac_sha256 hmac_sha256_hex/;
use DateTime::Format::Strptime qw/strptime/;

our $ALGORITHM = 'AWS4-HMAC-SHA256';

=head1 NAME

Net::Amazon::Signature - Implements the Amazon Web Services signature version 4, AWS4-HMAK-SHA256

=head1 VERSION

Version 0.03

=cut

our $VERSION = '0.03';


=head1 SYNOPSIS

This module signs an HTTP::Request to Amazon Web Services by appending an Authorization header. Amazon Web Services signature version 4, AWS4-HMAK-SHA256, is used.

    use Net::Amazon::Signature;

    my $sig = Net::Amazon::Signature->new( $account_id, $secret, $endpoint, $service );
	my $req = HTTP::Request->parse( $request_string );
	my $signed_req = $sig->sign( $req );
    ...

The primary purpose of this module is to be used by Net::Amazon::Glacier.

=head1 SUBROUTINES

=head2 new

=cut

sub new {
	my $class = shift;
	my ( $account_id, $secret, $endpoint, $service ) = @_;
	my $self = {
		account_id => $account_id,
		secret     => $secret,
		endpoint   => $endpoint,
		service    => $service,
	};
	bless $self, $class;
	return $self;
}

=head2 sign

=cut

sub sign {
	my ( $self, $request ) = @_;
	my $authz = $self->_authorization( $request );
	$request->header( Authorization => $authz );
	return $request;
}

# _canonical_request:
# Construct the canonical request string from an HTTP::Request.

sub _canonical_request {
	my ( $self, $req ) = @_;

	my $creq_method = $req->method;

	my ( $creq_canonical_uri, $creq_canonical_query_string ) = 
		( $req->uri =~ m@(.*)\?(.*)$@ )
		? ( $1, $2 )
		: ( $req->uri, '' );
	$creq_canonical_uri =~ s@^http://.*?/@/@;
	$creq_canonical_query_string = _sort_query_string( $creq_canonical_query_string );

	my @sorted_headers = sort { lc($a) cmp lc($b) } $req->headers->header_field_names;
	my $creq_canonical_headers = join '',
		map {
			sprintf "%s:%s\n",
				lc,
				join ',', sort {$a cmp $b } _trim_whitespace($req->header($_) )
		}
		@sorted_headers;
	my $creq_signed_headers = join ';', map {lc} @sorted_headers;
	my $creq_payload_hash = sha256_hex( $req->content );

	my $creq = join "\n",
		$creq_method, $creq_canonical_uri, $creq_canonical_query_string,
		$creq_canonical_headers, $creq_signed_headers, $creq_payload_hash;
	return $creq;
}

# _string_to_sign
# Construct the string to sign.

sub _string_to_sign {
	my ( $self, $req ) = @_;
	my $dt = _str_to_datetime( $req->header('Date') );
	my $creq = $self->_canonical_request($req);
	my $sts_request_date = $dt->strftime( '%Y%m%dT%H%M%SZ' );
	my $sts_credential_scope = join '/', $dt->strftime('%Y%m%d'), $self->{endpoint}, $self->{service}, 'aws4_request';
	my $sts_creq_hash = sha256_hex( $creq );

	my $sts = join "\n", $ALGORITHM, $sts_request_date, $sts_credential_scope, $sts_creq_hash;
	return $sts;
}

# _authorization
# Construct the authorization string

sub _authorization {
	my ( $self, $req ) = @_;

	my $dt = _str_to_datetime( $req->header('Date') );
	my $sts = $self->_string_to_sign( $req );
	my $k_date    = hmac_sha256( $dt->strftime('%Y%m%d'), 'AWS4' . $self->{secret} );
	my $k_region  = hmac_sha256( $self->{endpoint},        $k_date    );
	my $k_service = hmac_sha256( $self->{service},         $k_region  );
	my $k_signing = hmac_sha256( 'aws4_request',           $k_service );

	my $authz_signature = hmac_sha256_hex( $sts, $k_signing );
	my $authz_credential = join '/', $self->{account_id}, $dt->strftime('%Y%m%d'), $self->{endpoint}, $self->{service}, 'aws4_request';
	my $authz_signed_headers = join ';', sort { $a cmp $b } map { lc } $req->headers->header_field_names;

	my $authz = "$ALGORITHM Credential=$authz_credential, SignedHeaders=$authz_signed_headers, Signature=$authz_signature";
	return $authz;

}

=head1 AUTHOR

Tim Nordenfur, C<< <tim at gurka.se> >>

=cut

sub _sort_query_string {
	return '' unless $_[0];
	join '&', sort { $a cmp $b } split /&/, $_[0];
}
sub _trim_whitespace {
	return map { s/^\s*(.*?)\s*$/$1/; $_ } @_;
}
sub _str_to_datetime {
	my $date = shift;
	if ( $date =~ m/^\d{8}T\d{6}Z$/ ) {
		# assume basic ISO 8601, as demanded by AWS
		return strptime( '%Y%m%dT%H%M%SZ', $date );
	} else {
		# assume the format given in the AWS4 test suite
		$date =~ s/^.{4}//; # remove weekday, as Amazon's test suite contains internally inconsistent dates
		return strptime(  '%d %b %Y %H:%M:%S %Z', $date );
	}
}

=head1 BUGS

Please report any bugs or feature requests to C<bug-net-amazon-signature at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-Amazon-Signature>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Net::Amazon::Signature


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Net-Amazon-Signature>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Net-Amazon-Signature>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Net-Amazon-Signature>

=item * Search CPAN

L<http://search.cpan.org/dist/Net-Amazon-Signature/>

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2012 Tim Nordenfur.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Net::Amazon::Signature
