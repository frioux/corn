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

sub _lacks ($item, $string) { index($item->content->body, $string) == -1 }
sub _risingtensions ($self) {
   feed(
      'http://risingtensions.tumblr.com/rss',
      sub ($s) {
         $s->grep(sub {
            $_->title !~ m/(?:Audio|Video)/i             &&
            _lacks($_,'http://www.tumblr.com/video/')    &&
            _lacks($_, 'https://w.soundcloud.com')       &&
            _lacks($_, 'tumblr_video_container')         &&
            _lacks($_, 'https://www.youtube.com/embed/')
         });
      },
   )->get
}

sub _lwn ($self, $commit) {
   feed(
      'http://lwn.net/headlines/newrss',
      sub ($s) {
         $s->map(sub {
            $_->title($_->title =~ s/\[\$\]//r)
               if $_->title =~ m/\[\$\]/ &&
                  _do_req($_->link->href)->then_done(1)->else_done(0)->get;
            return $_
         })->grep(sub { $_->title !~ m/\[\$\]/ });
      },
      'LWN',
      $commit,
   )->get
}

sub _cpantesters ($self) {
   feed(
      'http://www.cpantesters.org/author/F/FREW-nopass.rss',
      sub ($s) {
         $s->grep(sub {
            $_->title !~ m(
               DBIx-Class-Journal |
               DBIx-Class-Helpers-2\.013002 |
               Jemplate |
               DBIx-Class-DigestColumns |
               Web-Simple |
               SQL-Translator |
               SQL-Abstract-1\.73 |
               DBIx-Class-0\.08207 |
               Test-EOL |
               DBIx-Class-MaterializedPath
            )xi
         });
      },
   )->get
}

sub _200_rss ($self, $rss) {
   [ 200, [ 'Content-type', 'application/atom+xml' ], [ $rss->as_xml ] ]
}

sub dispatch_request {
   'GET + ?commit~' => sub ($self, $commit = 0, @) {
     '/lwn'            => sub ($s, @) { $s->_200_rss($s->_lwn($commit))   },
     '/risingtensions' => sub ($s, @) { $s->_200_rss($s->_risingtensions) },
     '/cpantesters'    => sub ($s, @) { $s->_200_rss($s->_cpantesters)    },
  },
}

__PACKAGE__->run_if_script;
