#!/usr/bin/env perl

use 5.20.0;
use warnings;
use autodie;

use experimental 'signatures';

use Feed::Pipe;
use XML::Feed;
use Future;
use LWP::UserAgent;

sub feed ($url, $name, $commit = 0, $transform = sub { $_[0] }) {
   _do_req($url)
   ->then(sub ($res) {
      my %seen;

      my $path = "./$name.xml";

      my $f = Feed::Pipe->new
         ->cat(\($res->decoded_content), ( -f $path ? ($path) : ()))
         ->grep(sub { !($seen{$_->id}++) })
         ->grep(sub { $_->issued gt '' . DateTime->now->subtract(days => 30) });
      my $a = $f->as_atom_obj;

      if ($commit) {
         my $xml = $a->as_xml;
         open my $fh, '>', $path;
         print $fh $xml;
      }

      Future->done($f->$transform)
   });
}

my $commit = shift;

my $f = feed(
   'http://lwn.net/headlines/newrss',
   'LWN',
   $commit,
   sub ($s) {
      $s->map(sub {
         if ($_->title =~ m/\[\$\]/) {
            $_->title($_->title =~ s/\[\$\]//)
               if _do_req($_->link->href )
                  ->then_done(1)
                  ->else_done(0)
                  ->get;
         }
         return $_
      })->grep(sub { $_->title !~ m/\[\$\]/ });
   },
)->get;

say $f->as_xml;

sub _do_req ($url) {
   my $ua = LWP::UserAgent->new;
   $ua->timeout(10);
   my $response = $ua->get($url);

   if ($response->is_success) {
      return Future->done($response)
   } else {
      return Future->fail($response)
   }
}
