package Koha::Plugin::Com::PTFSEurope::CLAPermissionsCheck::ProxyController;

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;

use Koha::Plugin::Com::PTFSEurope::CLAPermissionsCheck;

use Mojo::Base 'Mojolicious::Controller';

use Digest::SHA qw( sha256_hex );
use Try::Tiny;

use Mojo::UserAgent;
use Mojo::JSON;

=head1 API

=head2 Class Methods

=head3 get

Get proxied response

=cut

sub get {

    my $c = shift->openapi->valid_input or return;

    my $check_permissions =
      Koha::Plugin::Com::PTFSEurope::CLAPermissionsCheck->new;

    return try {
        my $key        = $check_permissions->retrieve_data('key');
        my $type       = $c->param('identifier_type');
        my $identifier = $c->param('identifier');
        my $licence    = $c->param('licence');
        my $hash       = sha256_hex( $key . $identifier . time );

        my $url =
'https://api.cla.co.uk/check-permissions/v1/GetPermissionByIdentifier/'
          . $type . '/'
          . $identifier . '/'
          . $licence
          . "?userTypes=1,2"
          . "&messageId="
          . $hash
          . "&htmlToggle=true";

        my $ua = Mojo::UserAgent->new;

        my $res =
          $ua->get( $url,
            { 'Accept' => '*/*', 'Ocp-Apim-Subscription-Key' => $key } )
          ->result;

        if ( $res->is_success ) {
            return $c->render( status => 200, openapi => $res->json );
        }
        elsif ( $res->is_error ) {
            warn $res->message;
            warn $res->body;
        }
    }
    catch {
        return $c->render(
            status  => 500,
            openapi => { error => 'Something went wrong' }
        );
    }
}

1;
