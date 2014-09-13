#!/usr/bin/env perl

package MyFilter;

use Web::Simple;

use 5.20.0;
use warnings NONFATAL => 'all';

use autodie;

use experimental 'signatures';

use Feed::Pipe;
use XML::Feed;
use Future;
use LWP::UserAgent;

sub feed ($url, $transform = sub { $_[0] }, $name = '', $commit = 0) {
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

sub _risingtensions_content ($self) {
   feed(
      'http://risingtensions.tumblr.com/rss',
      sub ($s) {
         $s->grep(sub { index($_->content->body, 'http://www.tumblr.com/video/') == -1 });
      },
   )->get
}

sub _lwn_content ($self, $commit) {
   feed(
      'http://lwn.net/headlines/newrss',
      sub ($s) {
         $s->map(sub {
            $_->title($_->title =~ s/\[\$\]//)
               if $_->title =~ m/\[\$\]/ &&
                  _do_req($_->link->href)->then_done(1)->else_done(0)->get;
            return $_
         })->grep(sub { $_->title !~ m/\[\$\]/ });
      },
      'LWN',
      $commit,
   )->get
}

sub dispatch_request {
   'GET + ?commit~' => sub ($self, $commit = 0, @) {
     '/lwn' => sub {
        [ 200,
           [ 'Content-type', 'application/atom+xml' ],
           [ $self->_lwn_content($commit)->as_xml ],
        ]
     },
     '/risingtensions' => sub {
        [ 200,
           [ 'Content-type', 'application/atom+xml' ],
           [ $self->_risingtensions_content->as_xml ],
        ]
     },
  },
}

__PACKAGE__->run_if_script;