package TestApp::Controller::Crash;

use Moose;
use namespace::autoclean;
BEGIN
{
    extends 'Catalyst::Controller::HTML::FormFu';
    with 'OpusVL::AppKit::RolesFor::Controller::GUI';
}

__PACKAGE__->config
(
    appkit_myclass => 'TestApp',
);


sub index
    : Path
    : Public
{
    my ($self, $c) = @_;
    die 'Boom!';
}

1;

