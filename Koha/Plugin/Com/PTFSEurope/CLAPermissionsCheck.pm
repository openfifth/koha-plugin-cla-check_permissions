package Koha::Plugin::Com::PTFSEurope::CLAPermissionsCheck;

use Modern::Perl;

use base qw(Koha::Plugins::Base);
use Koha::DateUtils qw( dt_from_string );

use Cwd qw(abs_path);
use CGI;
use Business::ISBN;
use Business::ISSN;
use Digest::SHA qw( sha256_hex );
use LWP::UserAgent;
use HTTP::Request;
use JSON qw( decode_json );

our $VERSION = "1.0.10";

our $metadata = {
    name            => 'CLA Check Permissions',
    author          => 'Andrew Isherwood',
    date_authored   => '2018-06-18',
    date_updated    => "2019-07-02",
    minimum_version => '18.05.00.000',
    maximum_version => undef,
    version         => $VERSION,
    description     => 'This plugin provides CLA Check Permissions'
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
    my ($self, $args) = @_;

    return $self->retrieve_data('intranet_catalog_biblio_enhancements') eq 'Yes';
}

sub intranet_catalog_biblio_enhancements_toolbar_button {
    my ($self) = @_;
    my $template = $self->get_template({
        file => 'toolbar-button.tt'
    });
    $template->param(
        biblionumber => scalar $self->{cgi}->param('biblionumber')
    );
    return $template->output;
}

sub get_link {
    my ($self) = @_;

    return "Link";
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

    foreach my $isbn(@str_arr) {
        # Clean unwanted characters
        $isbn =~ s/[^0-9X]//g;
        # Only go further if we've got something left
        next unless $isbn;
        # Force to uppercase
        $isbn = uc $isbn;
        # Check whether we've ended up with a valid ISBN
        # if so, keep it
        my $isbn_obj = Business::ISBN->new($isbn);
        if ($isbn_obj && $isbn_obj->is_valid) {
            my $final = ($isbn_obj->type eq 'ISBN10') ?
                $isbn_obj->as_isbn10->isbn :
                $isbn_obj->as_isbn13->isbn;
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

    foreach my $issn(@str_arr) {
        my $issn_obj = Business::ISSN->new($issn);
        push @out, $issn_obj->as_string if $issn_obj->is_valid;
    }
    return @out;
}

sub check_start {
    my ($self, $args) = @_;

    my $template = $self->get_template({
        file => 'check_start.tt'
    });

    # The biblio we're working with
    my $biblionumber = $self->{cgi}->param('biblionumber');
    my $biblio = Koha::Biblios->find( $biblionumber );
    $template->param(
        biblio => $biblio
    );

    # Find an ISBN or ISSN as required by CLA
    my $biblioitems = Koha::Biblioitems->search({
        biblionumber => $biblionumber
    });

    my $candidates = {
        ISBN => [],
        ISSN => [] 
    };
    while (my $item = $biblioitems->next) {
        push(@{$candidates->{ISBN}}, clean_isbn($item->isbn));
        push(@{$candidates->{ISSN}}, clean_issn($item->issn));
    }

    # We didn't find any ISBN or ISSN
    if (scalar @{$candidates->{ISBN}} == 0 && scalar @{$candidates->{ISSN}} == 0) {
        $template->param(
            errors => ['Unable to find ISBN or ISSN for record']
        );
        $self->output_html( $template->output() );
        exit;
    }

    # We can't meaningfully evaluate which is the best identifier to
    # use, so we'll just use the first one we found
    my $to_pass = {};
    if (scalar @{$candidates->{ISBN}} > 0) {
        $to_pass = {
            identifier_type  => 'ISBN',
            identifier => $candidates->{ISBN}[0]
        };
    } else {
        $to_pass = {
            identifier_type  => 'ISSN',
            identifier => $candidates->{ISSN}[0]
        };
    }
    $template->param(
        identifier      => $to_pass->{identifier},
        identifier_type => $to_pass->{identifier_type}
    );

    # Populate the API key & licence
    $template->param(
        key => $self->retrieve_data('key'),
        licence => $self->retrieve_data('licence')
    );


    # Populate a hash based on our key and identifier and a timestamp
    # This will be used as a unique request ID
    $template->param(
        hash => sha256_hex(
            $self->retrieve_data('key') .
            $to_pass->{identifier} .
            time
        )
    );

    $self->output_html( $template->output() );
}

sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('save') ) {

        my $key = $self->retrieve_data('key');
        my $licence = $self->retrieve_data('licence');
        my $template = $self->get_template({ file => 'configure.tt' });

        my $ua = LWP::UserAgent->new;
        my $req = HTTP::Request->new(GET => 'https://api.cla.co.uk/check-permissions/v1/LicenceTypesAndUsages?messageId=' . time);
        $req->header('Ocp-Apim-Subscription-Key' => $key);
        my $res = $ua->request($req);
        if ($res->is_success) {
            $template->param(types => decode_json($res->content));
        }

        $template->param(
            key => $key,
            licence => $licence
        );

        $self->output_html( $template->output() );
    }
    else {
        my $p = { map { $_ => (scalar $cgi->param($_))[0] } $cgi->param };
        my $store = {};
        if (exists $p->{key}) {
            $store->{key} = $p->{key};
            if (exists $p->{licence}) {
                $store->{licence} = $p->{licence};
                $self->store_data($store);
                $self->go_home();
            }
            $self->store_data($store);
        } else {
            $store->{key} = '';
            $store->{licence} = '';
            $self->store_data($store);
        }
        print $cgi->redirect(-url => '/cgi-bin/koha/plugins/run.pl?class=Koha::Plugin::Com::PTFSEurope::CLAPermissionsCheck&method=configure');
        exit;
    }
}

sub install() {
    return 1;
}

sub upgrade {
    my ( $self, $args ) = @_;

    my $dt = dt_from_string();
    $self->store_data(
        { last_upgraded => $dt->ymd('-') . ' ' . $dt->hms(':') }
    );

    return 1;
}

sub uninstall() {
    return 1;
}

1;
