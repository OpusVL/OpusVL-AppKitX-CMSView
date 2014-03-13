package OpusVL::AppKitX::CMSView;
use Moose::Role;
use CatalystX::InjectComponent;
use File::ShareDir qw/module_dir/;
use namespace::autoclean;
use HTML::Entities;

with 'OpusVL::AppKit::RolesFor::Plugin';

our $VERSION = '0.66';

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
    my $view = $class->view('CMS::Page');
    my $template_path = module_dir(__PACKAGE__) . '/root/templates';
    unless ($view->include_path ~~ $template_path) {
        push @{$view->include_path}, $template_path;
    }
};

sub finalize_error {
    my $c = shift;

    # NOTE: catalyst appears to have logged the error already by this point.
    # my $error = join '<br/> ', map { encode_entities($_) } @{ $c->error };
    # $error ||= 'No output';
    # $c->log->error($error);

	$c->response->status(500);
    my $host = $c->req->uri->host;
    my $root = $c->controller('Root');
    my $site = $root->_get_site($c, { host => $host });
    $c->stash->{template} = '500.tt';
    if($site)
    {
        my $pages = $site->pages;
        my $page = $pages->published->find({url => '/500'});
        if($page)
        {
            $root->render_page($c, $page, $host);
        }
    }
    $c->view('CMS::Page')->process($c);
}

1;

=head1 NAME

OpusVL::AppKitX::CMSView - CMS front end

=head1 DESCRIPTION

=head1 METHODS

=head1 BUGS

=head1 AUTHOR

=head1 COPYRIGHT and LICENSE

Copyright (C) 2012 OpusVL

This software is licensed according to the "IP Assignment Schedule" provided with the development project.

=cut

