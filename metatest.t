#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Time::HiRes 'gettimeofday', 'tv_interval';

$ENV{PYTHONPATH} = '/home/frew/code/skunk/feed-pype';

for my $feed (qw(lwn badnrad risingtensions cpantesters)) {
  `git checkout python`;
  my $py_t0 = [gettimeofday];
  system("python corn.py $feed '' > python.xml");
  my $py_total = sprintf '%0.2f', tv_interval($py_t0);
  `git checkout master`;
  my $pl_t0 = [gettimeofday];
  system("perl app.psgi /$feed > perl.xml");
  my $pl_total = sprintf '%0.2f', tv_interval($pl_t0);
  my $out = `./minimeta.sh`;
  system('rm *.xml');
  ok(!$out, 'Same diff!') or diag("diff: $out");
  note("Times:\n   pl: $pl_total\n   py: $py_total");
}

done_testing;
