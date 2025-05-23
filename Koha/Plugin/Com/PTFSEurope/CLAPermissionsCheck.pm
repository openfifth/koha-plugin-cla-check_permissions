package Koha::Plugin::Com::PTFSEurope::CLAPermissionsCheck;

use Modern::Perl;

use base            qw(Koha::Plugins::Base);
use Koha::DateUtils qw( dt_from_string );

use Cwd qw(abs_path);
use CGI;
use JSON qw( encode_json );
use Business::ISBN;
use Business::ISSN;
use Digest::SHA qw( sha256_hex );
use LWP::UserAgent;
use HTTP::Request;
use Mojo::JSON qw( decode_json );

our $VERSION = "2.0.0";

our $metadata = {
    name            => 'CLA Check Permissions',
    author          => 'Open Fifth',
    date_authored   => '2018-06-18',
    date_updated    => "2025-05-23",
    minimum_version => '24.11.00.000',
    maximum_version => undef,
    version         => $VERSION,
    description     => 'This plugin provides CLA Check Permissions to the catalog detail page and the Standard ILL create form'
};

sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    $self->{cgi} = CGI->new();

    return $self;
}

sub intranet_catalog_biblio_enhancements {
    my ( $self, $args ) = @_;

    return $self->retrieve_data('intranet_catalog_biblio_enhancements') eq
      'Yes';
}

sub cla_button_tmpl {
    my ($self)        = @_;
    my $template      = $self->get_template( { file => 'tmpl/toolbar-button.tt' } );

    $template->param( licence => $self->retrieve_data('licence') );

    return $template->output;
}

sub cla_modal_tmpl {
    my ($self) = @_;
    my $template = $self->get_template( { file => 'tmpl/cla-modal.tt' } );

    return $template->output;
}

sub intranet_catalog_biblio_enhancements_toolbar_button {
    my ($self) = @_;
    my $template = $self->get_template(
        {
            file => 'tmpl/catalog-toolbar-button.tt'
        }
    );
    my $biblionumber = $self->{cgi}->param('biblionumber');
    my $biblioitem =
      Koha::Biblioitems->search( { biblionumber => $biblionumber },
        { rows => 1 } )->single;

    if ( my $isbn = $biblioitem->isbn ) {
        my @cleaned = clean_isbn($isbn);
        if (@cleaned) {
            $template->param( type       => 'isbn' );
            $template->param( identifier => $cleaned[0] );
        }
    }
    elsif ( my $issn = $biblioitem->issn ) {
        my @cleaned = clean_issn($isbn);
        if (@cleaned) {
            $template->param( type       => 'issn' );
            $template->param( identifier => $cleaned[0] );
        }
    }

    $template->param( licence => $self->retrieve_data('licence') );
    return $template->output;
}

sub clean_isbn {

    my $str = shift;

    return () unless $str;

    # We may have multiple ISBNs in this string, so attempt to separate
    # them
    my @str_arr = split /[\,,\|,\;]/, $str;

    # Clean each resulting string and force it to uppercase (we need an
    # uppercase X)
    my @out = ();

    foreach my $isbn (@str_arr) {

        # Clean unwanted characters
        $isbn =~ s/[^0-9X]//g;

        # Only go further if we've got something left
        next unless $isbn;

        # Force to uppercase
        $isbn = uc $isbn;

        # Check whether we've ended up with a valid ISBN
        # if so, keep it
        my $isbn_obj = Business::ISBN->new($isbn);
        if ( $isbn_obj && $isbn_obj->is_valid ) {
            my $final =
              ( $isbn_obj->type eq 'ISBN10' )
              ? $isbn_obj->as_isbn10->isbn
              : $isbn_obj->as_isbn13->isbn;
            push @out, $final;
        }
    }
    return @out;
}

sub clean_issn {

    my $str = shift;

    return () unless $str;

    # We may have multiple ISSNs in this string, so attempt to separate
    # them
    my @str_arr = split /[\,,\|,\;]/, $str;

    # Check each resulting string and if it looks like a likely
    # candidate, add it to the return array
    my @out = ();

    foreach my $issn (@str_arr) {
        my $issn_obj = Business::ISSN->new($issn);
        push @out, $issn_obj->as_string if $issn_obj->is_valid;
    }
    return @out;
}

sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('save') ) {

        my $key      = $self->retrieve_data('key');
        my $licence  = $self->retrieve_data('licence');
        my $template = $self->get_template( { file => 'configure.tt' } );

        my $ua = LWP::UserAgent->new;
        my $req =
          HTTP::Request->new( GET =>
'https://api.cla.co.uk/check-permissions/v1/LicenceTypesAndUsages?messageId='
              . time );
        $req->header( 'Ocp-Apim-Subscription-Key' => $key );
        my $res = $ua->request($req);
        if ( $res->is_success ) {
            $template->param( types => decode_json( $res->content ) );
        }

        $template->param(
            key     => $key,
            licence => $licence
        );

        $self->output_html( $template->output() );
    }
    else {
        my $p     = { map { $_ => ( scalar $cgi->param($_) )[0] } $cgi->param };
        my $store = {};
        if ( exists $p->{key} ) {
            $store->{key} = $p->{key};
            if ( exists $p->{licence} ) {
                $store->{licence} = $p->{licence};
                $self->store_data($store);
                $self->go_home();
            }
            $self->store_data($store);
        }
        else {
            $store->{key}     = '';
            $store->{licence} = '';
            $self->store_data($store);
        }
        print $cgi->redirect( -url =>
'/cgi-bin/koha/plugins/run.pl?class=Koha::Plugin::Com::PTFSEurope::CLAPermissionsCheck&method=configure'
        );
        exit;
    }
}

sub api_namespace {
    my ($self) = @_;

    return 'cla_check_permissions';
}

sub api_routes {
    my ( $self, $args ) = @_;

    my $spec_str = $self->mbf_read('api.json');
    my $spec     = decode_json($spec_str);

    return $spec;
}

sub static_routes {
    my ( $self, $args ) = @_;

    my $spec_str = $self->mbf_read('static.json');
    my $spec     = decode_json($spec_str);

    return $spec;
}

sub intranet_js {
    my ($self) = @_;

    my $cla_button_tmpl = $self->cla_button_tmpl();
    my $cla_modal_tmpl  = $self->cla_modal_tmpl();

    my $script = '<script>';
    $script .= 'const cla_permissions_check_plugin_license = ' . encode_json( $self->retrieve_data('licence') ) . ';';
    if( $cla_button_tmpl && $cla_modal_tmpl ) {
        $script .= 'const cla_modal_tmpl = ' . encode_json($cla_modal_tmpl) . ';';
        $script .= 'const cla_button_tmpl = ' . encode_json($cla_button_tmpl) . ';';
    }
    $script .= $self->mbf_read('checker.js');
    $script .= '</script>';

    return $script;
}

sub install() {
    return 1;
}

sub upgrade {
    my ( $self, $args ) = @_;

    my $dt = dt_from_string();
    $self->store_data(
        { last_upgraded => $dt->ymd('-') . ' ' . $dt->hms(':') } );

    return 1;
}

sub uninstall() {
    return 1;
}

1;
