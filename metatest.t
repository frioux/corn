#!/usr/bin/env perl

use strict;
use warnings;

use Capture::Tiny 'capture_merged';
use Process::Status;

use Test::More;
use Time::HiRes 'gettimeofday', 'tv_interval';

for my $feed (qw(lwn badnrad risingtensions cpantesters)) {
  my ($py_t0, $py_total, $pl_t0, $pl_total);
  my $out = capture_merged {
    system qw( git checkout python );
    $py_t0 = [gettimeofday];
    system "python corn.py $feed '' > $feed-python.xml";
    $py_total = sprintf '%0.2f', tv_interval($py_t0);
  };
  die "$out" unless Process::Status->new->is_success;

  $out = capture_merged {
    system qw(git checkout perl);
    $pl_t0 = [gettimeofday];
    system "perl app.psgi /$feed > $feed-perl.xml";
    $pl_total = sprintf '%0.2f', tv_interval($pl_t0);
  };
  die "$out" unless Process::Status->new->is_success;

  $out = `./minimeta.sh $feed`;
  unlink 'LWN.xml';
  ok(!$out, 'Same diff!') or diag("diff: $out");
  note("Times:\n   pl: $pl_total\n   py: $py_total");
}

done_testing;
