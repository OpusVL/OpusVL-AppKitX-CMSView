package OpusVL::AppKitX::CMSView;
use Moose::Role;
use CatalystX::InjectComponent;
use File::ShareDir qw/module_dir/;
use namespace::autoclean;

with 'OpusVL::AppKit::RolesFor::Plugin';

our $VERSION = '0.56';

after 'setup_components' => sub {
    my $class = shift;
   
    $class->add_paths(__PACKAGE__);
    
    # .. inject your components here ..
    CatalystX::InjectComponent->inject(
        into      => $class,
        component => 'OpusVL::AppKitX::CMSView::Model::CMS',
        as        => 'Model::CMS'
    );

    CatalystX::InjectComponent->inject(
        into      => $class,
        component => 'OpusVL::AppKitX::CMSView::View::CMS',
        as        => 'View::CMS::Page'
    );

    CatalystX::InjectComponent->inject(
        into      => $class,
        component => 'OpusVL::AppKitX::CMSView::View::CMS',
        as        => 'View::CMS::Element'
    );

    CatalystX::InjectComponent->inject(
        into      => $class,
        component => 'OpusVL::AppKitX::CMSView::View::Thumbnail',
        as        => 'View::CMS::Thumbnail'
    );
};

1;

=head1 NAME

OpusVL::AppKitX::CMS - 

=head1 DESCRIPTION

=head1 METHODS

=head1 BUGS

=head1 AUTHOR

=head1 COPYRIGHT and LICENSE

Copyright (C) 2012 OpusVL

This software is licensed according to the "IP Assignment Schedule" provided with the development project.

=cut

