package Koha::Plugin::Com::PTFSEurope::CLAPermissionsCheck;

use Modern::Perl;

use base qw(Koha::Plugins::Base);

use Cwd qw(abs_path);
use CGI;

our $VERSION = "0.0.1";

our $metadata = {
    name            => 'CLA Check Permissions',
    author          => 'Andrew Isherwood',
    date_authored   => '2018-06-18',
    date_updated    => "2018-06-18",
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

sub get_toolbar_button {
    my ($self) = @_;
    my $template = $self->get_template({
        file => 'toolbar-button.tt'
    });
    $template->param(
        biblionumber => $self->{cgi}->param('biblionumber')
    );
    return $template->output;
}

sub get_link {
    my ($self) = @_;

    return "Link";
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
