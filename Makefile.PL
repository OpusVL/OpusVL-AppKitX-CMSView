use strict;
use warnings;
use inc::Module::Install 0.91;
use Module::Install::AuthorRequires;
use Module::Install::AuthorTests;

name 'OpusVL-AppKitX-CMSView';
all_from 'lib/OpusVL/AppKitX/CMSView.pm';

requires 'Moose';
requires 'namespace::autoclean';
requires 'Catalyst::View::Thumbnail';
requires 'OpusVL::AppKit';
requires 'XML::RSS';
requires 'LWP::Simple';

build_requires 'Catalyst::Runtime' => '5.80015';
build_requires 'Test::WWW::Mechanize::Catalyst';
build_requires 'Test::More' => '0.88';

author_requires 'Test::Pod::Coverage' => '1.04';
author_requires 'Test::Pod' => '1.14';

author_tests 't/author';

resources repository => 'ssh://git/srv/git/OpusVL-AppKitX-CMSView';

if ($Module::Install::AUTHOR) {
    system("pod2text lib/OpusVL/AppKitX/CMSView.pm > README")
        and die $!;
}

WriteAll();
