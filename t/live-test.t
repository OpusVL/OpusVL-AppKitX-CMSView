#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

# setup library path
use FindBin qw($Bin);
use lib "$Bin/lib";

# make sure testapp works
use ok 'TestApp';

# a live test against TestApp, the test application
use Test::WWW::Mechanize::Catalyst 'TestApp';
my $mech = Test::WWW::Mechanize::Catalyst->new;

$mech->get_ok('http://localhost/', 'get main page');
$mech->content_like(qr/Woops! Something went wrong/i, 'see if it has our text');

subtest 'Crash test' => sub
{
    $mech->get('http://localhost/crash');
    is $mech->status, 500, 'Should return 500 response';
    $mech->content_like(qr/Please contact the site owner for assistance/i, 'Should contain generic error page'); 
    $mech->content_unlike(qr/Boom/, 'Should not contain actual crash details'); 

    done_testing;
};


done_testing;
