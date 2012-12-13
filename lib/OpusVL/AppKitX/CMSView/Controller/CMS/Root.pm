package OpusVL::AppKitX::CMSView::Controller::CMS::Root;

use 5.010;
use Moose;
use Scalar::Util 'looks_like_number';
use namespace::autoclean;
BEGIN { extends 'OpusVL::AppKit::Controller::Root'; };
 
__PACKAGE__->config( namespace => '');

sub default :Private {
    my ($self, $c) = @_;
    my $pages = $c->model('CMS::Page');
    my $url   = '/' . $c->req->path;
    my $host  = $c->req->uri->host;
    my $site;

    if (my $domain = $c->model('CMS::MasterDomain')->find({ domain => $host })) {
        if (my $redirect_domain = $domain->redirect_domains->first) {
            my $prot = $c->req->uri->secure ? 'https://' : 'http://';
            my $port = $c->req->uri->port;
            $host    = $redirect_domain->domain;
            $c->res->redirect("${prot}${host}:${port}${url}", 301);
            $c->detach;
        }

        $site = $domain->site;
    }
    elsif ($domain = $c->model('CMS::AlternateDomain')->find({ domain => $host })) {
        $site = $domain->master_domain->site;
    }
    elsif ($domain = $c->model('CMS::RedirectDomain')->find({ domain => $host })) {
        # no problem, we were probably redirected here
        $site = $domain->master_domain->site;
    }
    else {
        $self->throw_error($c, 'NO_HOST', { host => $host });
        $c->detach;
    }

    $c->log->debug("********** Running CMS lookup against: ${url} @ ${host}");

    # Does the URL match a page alias?
    if (my $alias = $c->model('CMS::Alias')->find({url => '/'.$c->req->path})) {
        $c->log->debug("Found page alias, redirecting...");
        $c->res->redirect($c->uri_for($alias->page->url), 301);
        $c->detach;
    }
    
    # Does the URL match a real page?
    my $page = $pages->search({ site => $site->id })->published->find({url => $url});
    
    # If not, do we have a page matching the current action?
    $page //= do {
        $pages->published->find({url => '/'.$c->action});
    };
    
    # If not, do we have a 404 page?
    $page //= do {
        $c->response->status(404);
        $pages->published->find({url => '/404'});
    };
    
    if ($page) {
        $site = $page->site;
        $c->stash->{me}  = $page;
        $c->stash->{cms} = {
            asset => sub {
                my $id = shift;
                if (looks_like_number $id) {
                    if (my $asset = $c->model('CMS::Asset')->available($site->id)->find({id => $id})) {
                        return $c->uri_for($c->controller('Root')->action_for('_asset'), $asset->id, $asset->filename);
                    }
                }
                else {
                    # not a number? then we may be looking for a logo!
                    if ($id eq 'logo') {
                        if (my $logo = $c->model('CMS::Asset')->available($site->id)->find({ description => 'Logo' })) {
                            return $c->uri_for($c->controller('Root')->action_for('_asset'), $logo->id, $logo->filename);
                        }
                        else {
                            if ($logo = $c->model('CMS::Asset')->available($site->id)->find({ global => 1, description => 'Logo' })) {
                                return $c->uri_for($c->controller('Root')->action_for('_asset'), $logo->id, $logo->filename);
                            }
                        }
                    }
                }
            },
            attachment => sub {
                if (my $attachment = $c->model('CMS::Attachment')->find({id => shift})) {
                    return $c->uri_for($c->controller('Root')->action_for('_attachment'), $attachment->id, $attachment->filename);
                }
            },
            element => sub {
                my ($id, $attrs) = @_;
                if ($attrs) {
                    foreach my $attr (%$attrs) {
                        $c->stash->{me}->{$attr} = $attrs->{$attr};
                    }
                }
                if (my $element = $c->model('CMS::Element')->available($site->id)->find({id => $id})) {
                    return $element->content;
                }
            },
            site_attr => sub {
                my $code = shift;
                if (my $attr = $site->site_attributes->find({ code => $code })) {
                    return $attr->value;
                }
            },
            page => sub {
                return $site->pages->published->find({id => shift});
            },
            pages => sub {
                return $site->pages->published->attribute_search(@_);
            },
            param => sub {
                return $c->req->param(shift);
            },
            toplevel => sub {
                return $site->pages->published->toplevel;
            },
            thumbnail => sub {
                return $c->uri_for($c->controller('Root')->action_for('_thumbnail'), @_);
            },
        };

        # load any plugins
        my @plugins = $c->model('CMS::Plugin')->search({ status => 'active' })->all;
        if (scalar @plugins > 0) {
          {
            no strict 'refs';
            foreach my $plugin (@plugins) {
              my $code = $plugin->code;
              $code !~ s/[^[:ascii:]]//g;
              $c->stash->{cms}->{plugin}->{ $plugin->action } = sub { eval($code) };
            }
          }
        }

        if (my $template = $page->template->content) {
            $template = '[% BLOCK content %]' . $page->content . '[% END %]' . $template;
            $c->stash->{template}   = \$template;
            $c->stash->{no_wrapper} = 1;
        }

        if ($c->req->uri =~ /\.txt$/) {
            $c->res->content_type("text/plain");
        }

        $c->forward($c->view('CMS::Page'));
    } else {
        OpusVL::AppKit::Controller::Root::default($self,$c);
    }
}

sub throw_error {
    my ($self, $c, $error, $opts) = @_;
    for (uc $error) {
        if (/^NO_HOST$/) {
            $error = "The host '$opts->{host}' could not be found";
        }
        else {
            $error = "An unknown error occurred";
        }
    }

    my $template .= qq{
        <!doctype html>
        <html>
            <head>
                <title>An error has occurred</title>
            </head>
            <body>
                <h1>Woops! Something went wrong</h1>
                <p>$error</p>
            </body>
        </html>
    };

    $c->stash->{template}   = \$template;
    $c->stash->{no_wrapper} = 1;
    $c->forward($c->view('CMS::Page'));
}

sub _asset :Local :Args(2) {
    my ($self, $c, $asset_id, $filename) = @_;
    
    if (my $asset = $c->model('CMS::Asset')->published->find({id => $asset_id})) {
        $c->response->content_type($asset->mime_type);
        $c->response->body($asset->content);
    } else {
        $c->response->status(404);
        $c->response->body("Not found");
    }
}

sub _attachment :Local :Args(2) {
    my ($self, $c, $attachment_id, $filename) = @_;
    
    if (my $attachment = $c->model('CMS::Attachment')->find({id => $attachment_id})) {
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
            if (my $asset = $c->model('CMS::Asset')->published->find({id => $id})) {
                $c->stash->{image} = $asset->content;
            }
        }
        when ('attachment') {
            if (my $attachment = $c->model('CMS::Attachment')->find({id => $id})) {
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
