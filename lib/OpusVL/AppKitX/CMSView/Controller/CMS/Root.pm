package OpusVL::AppKitX::CMSView::Controller::CMS::Root;

use 5.010;
use Moose;
use namespace::autoclean;
BEGIN { extends 'OpusVL::AppKit::Controller::Root'; };
 
__PACKAGE__->config( namespace => '');

sub default :Private {
    my ($self, $c) = @_;
    
    $c->log->debug("********** Running CMS lookup against:" . $c->req->path );

    # Does the URL match a page alias?
    if (my $alias = $c->model('CMS::Aliases')->find({url => '/'.$c->req->path})) {
        $c->log->debug("Found page alias, redirecting...");
        $c->res->redirect($c->uri_for($alias->page->url));
        $c->detach;
    }
    
    if (my $page = $c->model('CMS::Pages')->published->find({url => '/'.$c->req->path})) {
        $c->stash->{me}  = $page;
        $c->stash->{cms} = {
            asset => sub {
                if (my $asset = $c->model('CMS::Assets')->published->find({id => shift})) {
                    return $c->uri_for($c->controller->action_for('_asset'), $asset->id, $asset->filename);
                }
            },
            attachment => sub {
                if (my $attachment = $c->model('CMS::Attachments')->find({id => shift})) {
                    return $c->uri_for($c->controller->action_for('_attachment'), $attachment->id, $attachment->filename);
                }
            },
            element => sub {
                if (my $element = $c->model('CMS::Elements')->published->find({id => shift})) {
                    return $element->content;
                }
            },
            page => sub {
                return $c->model('CMS::Pages')->published->find({id => shift});
            },
            pages => sub {
                return $c->model('CMS::Pages')->published->attribute_search(@_);
            },
            param => sub {
                return $c->req->param(shift);
            },
            toplevel => sub {
                return $c->model('CMS::Pages')->published->toplevel;
            },
            thumbnail => sub {
                return $c->uri_for($c->controller->action_for('_thumbnail'), @_);
            },
        };
        
        if (my $template = $page->template->content) {
            $template = '[% BLOCK content %]' . $page->content . '[% END %]' . $template;
            $c->stash->{template}   = \$template;
            $c->stash->{no_wrapper} = 1;
        }
        
        $c->forward($c->view('CMS::Page'));
    } else {
        if (my $page = $c->model('CMS::Pages')->published->find({url => '/404'})) {
            $c->stash->{page} = $page;
            
            if (my $template = $page->template->content) {
                $c->stash->{template} = \$template;
                $c->stash->{no_wrapper} = 1;
            }
        } else {
            OpusVL::AppKit::Controller::Root::default($self,$c);
        }
    }
}

sub _asset :Local :Args(2) {
    my ($self, $c, $asset_id, $filename) = @_;
    
    if (my $asset = $c->model('CMS::Assets')->published->find({id => $asset_id})) {
        $c->response->content_type($asset->mime_type);
        $c->response->body($asset->content);
    } else {
        $c->response->status(404);
        $c->response->body("Not found");
    }
}

sub _attachment :Local :Args(2) {
    my ($self, $c, $attachment_id, $filename) = @_;
    
    if (my $attachment = $c->model('CMS::Attachments')->find({id => $attachment_id})) {
        $c->response->content_type($attachment->mime_type);
        $c->response->body($attachment->content);
    } else {
        $c->response->status(404);
        $c->response->body("Not found");
    }
}

sub _thumbnail :Local :Args(2) {
    my ($self, $c, $type, $id) = @_;
    
    given ($type) {
        when ('asset') {
            if (my $asset = $c->model('CMS::Assets')->published->find({id => $id})) {
                $c->stash->{image} = $asset->content;
            }
        }
        when ('attachment') {
            if (my $attachment = $c->model('CMS::Attachments')->find({id => $id})) {
                $c->stash->{image} = $attachment->content;
            }
        }
    }
    
    if ($c->stash->{image}) {
        $c->stash->{x}       = $c->req->param('x') || undef;
        $c->stash->{y}       = $c->req->param('y') || undef;
        $c->stash->{zoom}    = $c->req->param('zoom') || 100;
        $c->stash->{scaling} = $c->req->param('scaling') || 'fill';
        
        unless ($c->stash->{x} || $c->stash->{y}) {
            $c->stash->{y} = 50;
        }
        
        $c->forward($c->view('CMS::Thumbnail'));
    } else {
        $c->response->status(404);
        $c->response->body("Not found");
    }
}

sub index 
    :Path('/_admin') 
    :Args(0) 
    :AppKitFeature('Home Page')
{
    OpusVL::AppKit::Controller::Root::index(@_);
    #my ( $self, $c ) = @_;
    #
    #$c->_appkit_stash_portlets;
    #
    #$c->stash->{template} = 'index.tt';
    #$c->stash->{homepage} = 1;
}