#!/usr/bin/env perl

use 5.20.0;
use warnings;
use autodie;

use experimental 'signatures';

use Feed::Pipe;
use IO::Async::Loop;
use Net::Async::HTTP;
use URI;
use XML::Feed;
use DateTime::Format::Strptime;
use Try::Tiny;

my $loop = IO::Async::Loop->new;
my $http = Net::Async::HTTP->new;
$loop->add( $http );

sub feed ($url, $name, $commit = 0, $transform = sub { $_[0] }) {
   $http->do_request(
      uri => URI->new( $url ),
   )->then(sub ($res) {
      my %seen;

      my $path = "./$name.xml";

      my $f = Feed::Pipe->new
         ->cat(\($res->content), ( -f $path ? ($path) : ()))
         ->grep(sub { !($seen{$_->id}++) })
         ->grep(sub { $_->issued gt '' . DateTime->now->subtract(days => 30) });
      my $a = $f->as_atom_obj;

      if ($commit) {
         my $xml = $a->as_xml;
         open my $fh, '>', $path;
         print $fh $xml;
      }

      Future->wrap($f->$transform)
   });
}

my $commit = shift;

my $f = feed(
   'http://lwn.net/headlines/newrss',
   'LWN',
   $commit,
   sub ($s) {

      $s
         ->map(sub {
            if ($_->title =~ m/\[\$\]/) {
               my $ready_date = _forward_to_thu(_parse_dt($_->issued));
               $_->title($_->title =~ s/\[\$\]//)
                  if DateTime->now > $ready_date && $http->do_request( uri => URI->new( $_->link->href ) )
                  ->then(sub ($res) {
                     if ($res->content !~ 'this item will become freely available on ' . $ready_date->strftime('%B %d, %Y')) {
                        warn " !!! WTF $ready_date is different on the page!";
                        return Future->wrap(0)
                     }
                  })->get;

            }
            return $_
         })
         ->grep(sub { $_->title !~ m/\[\$\]/ });
   },
)->get;

say $f->as_xml;

sub _forward_to_thu ($dt) {
   my $ret = $dt->clone;

   while ($ret->day_name ne 'Thursday') {
      $ret = $ret->add(days => 1)
   }

   return $ret
}

sub _parse_dt ($str) {
   try {
      DateTime::Format::Strptime->new(
         pattern   => '%FT%TZ',
         locale    => 'en_US',
         time_zone => 'UTC',
         on_error  => 'croak',
      )->parse_datetime($str)
   } catch {
      die "$_: $str"
   }
}
