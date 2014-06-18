package OpusVL::AppKitX::CMSView::Controller::CMS::Root;

use 5.010;
use Encode;
use Moose;
use Scalar::Util 'looks_like_number';
use namespace::autoclean;
BEGIN { extends 'OpusVL::AppKit::Controller::Root'; };
 
__PACKAGE__->config( namespace => '');

sub _is_mobile_device :Private {
    my ($self, $c) = @_;
    my $agent      = $c->req->user_agent;
    if ($agent =~ m/android.+mobile|avantgo|bada\/|blackberry|blazer|compal|elaine|fennec|hiptop|iemobile|ip(hone|od)|iris|kindle|lge |maemo|meego.+mobile|midp|mmp|netfront|opera m(ob|in)i|palm( os)?|phone|p(ixi|re)\/|plucker|pocket|psp|series(4|6)0|symbian|treo|up\.(browser|link)|vodafone|wap|windows (ce|phone)|xda|xiino/i || substr($agent, 0, 4) =~ m/1207|6310|6590|3gso|4thp|50[1-6]i|770s|802s|a wa|abac|ac(er|oo|s\-)|ai(ko|rn)|al(av|ca|co)|amoi|an(ex|ny|yw)|aptu|ar(ch|go)|as(te|us)|attw|au(di|\-m|r |s )|avan|be(ck|ll|nq)|bi(lb|rd)|bl(ac|az)|br(e|v)w|bumb|bw\-(n|u)|c55\/|capi|ccwa|cdm\-|cell|chtm|cldc|cmd\-|co(mp|nd)|craw|da(it|ll|ng)|dbte|dc\-s|devi|dica|dmob|do(c|p)o|ds(12|\-d)|el(49|ai)|em(l2|ul)|er(ic|k0)|esl8|ez([4-7]0|os|wa|ze)|fetc|fly(\-|_)|g1 u|g560|gene|gf\-5|g\-mo|go(\.w|od)|gr(ad|un)|haie|hcit|hd\-(m|p|t)|hei\-|hi(pt|ta)|hp( i|ip)|hs\-c|ht(c(\-| |_|a|g|p|s|t)|tp)|hu(aw|tc)|i\-(20|go|ma)|i230|iac( |\-|\/)|ibro|idea|ig01|ikom|im1k|inno|ipaq|iris|ja(t|v)a|jbro|jemu|jigs|kddi|keji|kgt( |\/)|klon|kpt |kwc\-|kyo(c|k)|le(no|xi)|lg( g|\/(k|l|u)|50|54|\-[a-w])|libw|lynx|m1\-w|m3ga|m50\/|ma(te|ui|xo)|mc(01|21|ca)|m\-cr|me(di|rc|ri)|mi(o8|oa|ts)|mmef|mo(01|02|bi|de|do|t(\-| |o|v)|zz)|mt(50|p1|v )|mwbp|mywa|n10[0-2]|n20[2-3]|n30(0|2)|n50(0|2|5)|n7(0(0|1)|10)|ne((c|m)\-|on|tf|wf|wg|wt)|nok(6|i)|nzph|o2im|op(ti|wv)|oran|owg1|p800|pan(a|d|t)|pdxg|pg(13|\-([1-8]|c))|phil|pire|pl(ay|uc)|pn\-2|po(ck|rt|se)|prox|psio|pt\-g|qa\-a|qc(07|12|21|32|60|\-[2-7]|i\-)|qtek|r380|r600|raks|rim9|ro(ve|zo)|s55\/|sa(ge|ma|mm|ms|ny|va)|sc(01|h\-|oo|p\-)|sdk\/|se(c(\-|0|1)|47|mc|nd|ri)|sgh\-|shar|sie(\-|m)|sk\-0|sl(45|id)|sm(al|ar|b3|it|t5)|so(ft|ny)|sp(01|h\-|v\-|v )|sy(01|mb)|t2(18|50)|t6(00|10|18)|ta(gt|lk)|tcl\-|tdg\-|tel(i|m)|tim\-|t\-mo|to(pl|sh)|ts(70|m\-|m3|m5)|tx\-9|up(\.b|g1|si)|utst|v400|v750|veri|vi(rg|te)|vk(40|5[0-3]|\-v)|vm40|voda|vulc|vx(52|53|60|61|70|80|81|83|85|98)|w3c(\-| )|webc|whit|wi(g |nc|nw)|wmlb|wonu|x700|yas\-|your|zeto|zte\-/i) {
        return 1;
    }
}

sub _get_site
{
    my ($self, $c, $args) = @_;
    $args //= {};
    my $host = $args->{host} // $c->req->uri->host;
    my $url = $args->{url} // '/' . $c->req->path;

    my $site;
    if (my $domain = $c->model('CMS::MasterDomain')->find({ domain => $host })) {
        if (my $redirect_domain = $domain->redirect_domains->first) {
            return unless $args->{redirect_if_necessary};
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
    return $site;
}

sub render_page
{
    my ($self, $c, $page, $host, $display_errors) = @_;
    my $site = $page->site;
    $c->stash->{me}  = $page;
    $c->stash->{cms} = {
        img   => sub {
            my ($type, $slug, $align) = @_;
            if ($type and $slug) {
                $align = $align ? $align : 'center';
                my $img;
                for($type) {
                    if (/asset/) {
                        if (my $asset = $c->model('CMS::Asset')->available($site->id)->find({ slug => $slug })) {
                            $img = $c->uri_for($c->controller('Root')->action_for('_asset'), $slug, $asset->filename);
                        }
                    } elsif (/attachment/) {
                        if (my $att = $c->model('CMS::Attachment')->search({ slug => $slug })->first) {
                            $img = $c->uri_for($c->controller('Root')->action_for('_attachment'), $att->slug, $att->filename);
                        }
                    }
                }
                
                if ($img) {
                    return qq{<div style="text-align:$align"><img src="$img"></div>};
                }
            }
        },

        asset => sub {
            my $id = shift;
            if ($id eq 'logo') {
                if (my $logo = $site->assets->available($site->id)->find({ description => 'Logo' })) {
                    return $c->uri_for($c->controller('Root')->action_for('_asset'), $logo->slug, $logo->filename);
                }
                else {
                    if ($logo = $c->model('CMS::Asset')->available($site->id)->find({ global => 1, description => 'Logo' })) {
                        return $c->uri_for($c->controller('Root')->action_for('_asset'), $logo->slug, $logo->filename);
                    }
                }
            }

            elsif ($id eq 'icon') {
                if (my $icon = $site->assets->available($site->id)->find({ description => 'Icon' })) {
                    return $c->uri_for($c->controller('Root')->action_for('_asset'), $icon->id, $icon->filename);
                }
                else {
                    if ($icon = $c->model('CMS::Asset')->available($site->id)->find({ global => 1, description => 'Icon' })) {
                       return $c->uri_for($c->controller('Root')->action_for('_asset'), $icon->id, $icon->filename);
                    } 
                }
            }
            else {
                if (my $asset = $c->model('CMS::Asset')->available($site->id)->find({slug => $id})) {
                    return $c->uri_for($c->controller('Root')->action_for('_asset'), $id, $asset->filename);
                }
            }
        },
        attachment => sub {
            if (my $attachment = $c->model('CMS::Attachment')->search({slug => shift})->first) {
                return $c->uri_for($c->controller('Root')->action_for('_attachment'), $attachment->slug, $attachment->filename);
            }
        },
        element => sub {
            my ($id, $attrs) = @_;
            if ($attrs) {
                foreach my $attr (%$attrs) {
                    $c->stash->{me}->{$attr} = $attrs->{$attr};
                }
            }
            if (my $element = $c->model('CMS::Element')->available($site->id)->find({slug => $id})) {
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
            return $site->pages->published->attribute_search($site->id, @_);
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
        form      => sub {
            my $name = shift;
            return $site->forms->find({ name => $name });
        },
        site      => sub {
            my $opt = shift;
            given($opt) {
                when ('subdomain') {
                    my ($subdomain, $host, $tld) = split /\./, $host;
                    return $subdomain if $tld;
                }
            }
        }
    };

    # load any plugins
    my @plugins = $c->model('CMS::Plugin')->search({ status => 'active' })->all;
    if (scalar @plugins > 0) {
      {
        no strict 'refs';
        foreach my $plugin (@plugins) {
          my $code = $plugin->code;
          $code =~ s/[^[:ascii:]]//g;
          $c->stash->{cms}->{plugin}->{ $plugin->action } = sub { eval($code) };
        }
      }
    }

    if (my $template = $page->template->content) {
        if ($display_errors) {
            $template = '[% BLOCK content %]' . $display_errors . $page->content . '[% END %]' . $template;
        }
        else {
            $template = '[% BLOCK content %]' . $page->content . '[% END %]' . $template;
        }
        $c->stash->{template}   = \$template;
        $c->stash->{no_wrapper} = 1;
    }

    if ($c->req->uri =~ /\.txt$/) {
        $c->res->content_type("text/plain");
    }

    if ($page->content_type ne 'text/html') {
        $c->res->content_type( $page->content_type );
    }

}

sub default :Private {
    my ($self, $c) = @_;
    my $is_mobile = 0;
    my $orig_dom;
    my $domain;
    my $url   = '/' . $c->req->path;
    my $host  = $c->req->uri->host;

    if ($url =~ /^\/_asset\//) {
	    my @args = @{$c->req->arguments};
        if (@args > 2) {
            $c->res->status(404);
            $c->res->body("Not found");
            $c->detach;
        }

	    shift @args;
        return $self->_asset($c, @args);
    }

    if ($url =~ /^\/_attachment\//) {
        my @args = @{$c->req->arguments};
        #shift @args;
        return $self->_attachment($c, @args);
    }

    my $site = $self->_get_site($c, { host => $host, redirect_if_necessary => 1, url => $url });
    unless($site) 
    {
        $self->throw_error($c, 'NO_HOST', { host => $host });
        $c->detach;
    }

    my $pages = $site->pages;
    my $page = $pages->search({ site => $site->id })->published->find({url => $url});

    # using a mobile device
    if ($c->config->{mobile_redirection_service}) {
        if ($self->_is_mobile_device($c)) {
            if ($c->config->{mobile_redirection_service_extra}) {
                # uncomment this for full cmsview mobil redirection compatibility
                # check to see if they're on a fullsite (no m. domain)
                if ($host !~ /^m\./) {
                    if ($c->req->query_params->{mwf} eq 't') {
                        $c->session->{mobile_fullsite_pls} = 'yes, thanks';
                        $c->res->redirect($c->req->uri->path);
                        $c->detach;
                    }

                    if ($c->req->query_params->{mwf} eq 'f') {
                        delete $c->session->{mobile_fullsite_pls};
                    }

                    # did they action want the fullsite?
                    unless ($c->session->{mobile_fullsite_pls}) {
                        # is there a mobile site?
                        if (my $dom = $c->model('CMS::MasterDomain')->find({ domain => "m.${host}" })) {
                            my $full_site = $dom->site;
                            # is there a mobile page for it?
                            # if so, then redirect to that
                            if (my $chk_page = $full_site->pages->search({ site => $full_site->id })->published->find({ url => $url })) {
                                my $prot = $c->req->uri->secure ? 'https://' : 'http://';
                                my $port = $c->req->uri->port;
                                $c->res->redirect("${prot}m.${host}:${port}${url}");
                                $c->detach;
                            }
                            # no? then is there a full site page for it?
                            # and if not, send to mobile 404 page
                            if (not $page) {
                                $c->res->redirect('/404');
                                $c->detach;
                            }
                        } # end mobile site check
                    } # end session check
                } # end fullsite check
            }
            if ($host =~ /^m\./) {
                # strip off the www if we've found one
                if (substr($host, 2, 4) eq 'www.') {
                    substr($host, 2, 4) = '';
                }

                # get the full host (without the m. bit)
                my $fullhost = substr $host, 2;
                
                # if the mobile page does not exist
                # else, render as normal
                if (not $page) {
                    # does a full site exist?
                    if (my $dom = $c->model('CMS::MasterDomain')->find({ domain => $fullhost })) {
                        # try to get the page and go there
                        my $full_site = $dom->site;
                        if (my $chk_page = $full_site->pages->search({ site => $full_site->id })->published->find({ url => $url })) {
                           my $prot = $c->req->uri->secure ? 'https://' : 'http://';
                           my $port = $c->req->uri->port;
                           $c->res->redirect("${prot}${fullhost}:${port}${url}?mwf=t");
                           $c->detach;
                        }
                        # or show mobile 404
                        else {
                            $c->res->redirect('/404');
                            $c->detach;
                        }
                    }   
                }
            }
        } # end mobile device check
    } # end mobile_redirection_service config check

    $c->log->debug("********** Running CMS lookup against: ${url} @ ${host}");

    
    # If not, do we have a page matching the current action?
    $page //= do {
        $pages->published->find({url => '/'.$c->action});
    };
    
    # Does the URL match a page alias?
    unless ($page) {
        $c->log->debug("************** CHECKING ALIAS " . $c->req->path);
        if (my $alias = $c->model('CMS::Alias')->find_redirect($site, $c->req->path)) {
            $c->log->debug("Found page alias, redirecting...");
            $c->res->redirect($c->uri_for($alias->page->url), 301);
            $c->detach;
        }
    }

    # If not, do we have a 404 page?
    $page //= do {
        $c->response->status(404);
        $pages->published->find({url => '/404'});
    };

    
    my $display_errors;
    if ($page) {
        # form been submitted?
        if ($c->req->body_params) {
            my $params = $c->req->body_params;
            if (my $fid = $params->{form_id}) {
                if (my $form = $c->model('CMS::Form')->find($fid)) {
                    if (my $submit = $form->forms_submit_fields->first) {
                        # Form has been submitted!
                        my $value = $submit->value;
                        $value = lc $value;
                        $value =~ s/\s/_/g;
                        $value =~ s/[^\w\d\s]//g;
                        if ($params->{$value}) {
                            my @errors = $form->validate($params, $c->req->address);
                            
                            if (scalar @errors > 0) {
                                $display_errors = $self->_build_error(\@errors);
                            }
                            else {
                                $form->save($params)->email;
        ;                       $c->res->redirect($submit->redirect->url);
                            }
                        }
                    }
                }
            }
        }
        $self->render_page($c, $page, $host, $display_errors);
        $c->forward($c->view('CMS::Page'));
    } else {
        OpusVL::AppKit::Controller::Root::default($self,$c);
    }
}

sub _build_error {
    my ($self, $errors) = @_;
    my $errlist = "Please fix the errors below and re-submit your form\\n\\n";
    for my $err (@$errors) {
        $errlist .= "* ${err}\\n";
    }

    #return qq{
    #    <style type="text/css">
    #        .error_msg {
    #            width:100%;
    #            height:50px;
    #            display:block;
    #            position:absolute;
    #            top:0;
    #            left:0;
    #            background-color: #ccc;
    #            margin-bottom: 10px;
    #        }
    #        </style>
    #        <div class="error_msg">
    #            <p><strong>Please check the errors below and re-submit your form</strong></p>
    #            <ul>
    #                ${errlist}
    #            </ul>
    #        </div>
    #};

    return qq{
        <script type="text/javascript">
            alert("$errlist");
        </script>
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
    my $site = $self->_get_site($c);
    if ($filename) {
        if ($asset_id eq 'use') {
            if (my $asset = $c->model('CMS::Asset')->available($site->id)->search({ slug => $filename })->first) {
                $asset_id = $asset->id;
            }
            else {
                $c->res->status(404);
                $c->res->body("Not found");
            }
        }

        if (my $asset = $c->model('CMS::Asset')->available($site->id)->search({ slug => $asset_id })->first) {
            $c->response->content_type($asset->mime_type);
            $c->response->body($asset->content);
            $c->detach;
        }
        elsif ($asset = $c->model('CMS::Asset')->available($site->id)->search({id => $asset_id})->first) {
            $c->response->content_type($asset->mime_type);
            $c->response->body($asset->content);
            $c->detach;
        } else {
            $c->response->status(404);
            $c->response->body("Not found");
        }
    }
}

sub _attachment :Local :Args(2) {
    my ($self, $c, $attachment_id, $filename) = @_;
   
    my $site = $self->_get_site($c);
    if (my $attachment = $c->model('CMS::Attachment')->available($site->id)->search({ slug => $attachment_id })->first) {
        $c->res->content_type($attachment->mime_type);
        $c->res->body($attachment->content);
        $c->detach;
    } 
    elsif ($attachment = $c->model('CMS::Attachment')->available($site->id)->search({id => $attachment_id})->first) {
        $c->response->content_type($attachment->mime_type);
        $c->response->body($attachment->content);
        $c->detach;
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
