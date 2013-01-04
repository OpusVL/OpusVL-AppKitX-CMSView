package OpusVL::AppKitX::CMSView::View::CMS;

use Moose;

extends 'Catalyst::View::TT::Alloy';

__PACKAGE__->config({
  ENCODING => 'utf-8',
  AUTO_FILTER => 'none',
});

1;
