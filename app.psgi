#!/usr/bin/env perl

package MyFilter;

use Web::Simple;

use 5.18.0;
use warnings NONFATAL => 'all';

use autodie;

use Feed::Pipe;
use XML::Feed;
use Future;
use LWP::UserAgent;
use Try::Tiny;

$ENV{CORN_SILO} ||= '';

sub feed {
   my ($url, $transform, $name, $commit) = @_;
   $transform ||= sub { $_[0] };
   $name ||= '';
   $commit ||= 0;

   _do_req($url)
   ->then(sub {
      my $res = shift;
      my %seen;

      my $path = "$ENV{CORN_SILO}$name.xml";

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

sub _do_req {
   my $url = shift;
   my $ua = LWP::UserAgent->new;
   $ua->timeout(10);
   my $response = $ua->get($url);

   if ($response->is_success) {
      return Future->done($response)
   } else {
      return Future->fail($response)
   }
}

sub _lacks { index($_[0]->content->body, $_[1]) == -1 }
sub _risingtensions {
   feed(
      'http://risingtensions.tumblr.com/rss',
      sub {
         shift->grep(sub {
            $_->title !~ m/(?:Audio|Video)/i             &&
            _lacks($_,'http://www.tumblr.com/video/')    &&
            _lacks($_, 'https://w.soundcloud.com')       &&
            _lacks($_, 'tumblr_video_container')         &&
            _lacks($_, 'https://www.youtube.com/embed/')
         });
      },
   )->get
}

sub _badnrad {
   feed(
      'http://badnrad.tumblr.com/rss',
      sub {
         shift->grep(sub {
            $_->title !~ m/(?:Audio|Video)/i             &&
            _lacks($_,'http://www.tumblr.com/video/')    &&
            _lacks($_, 'https://w.soundcloud.com')       &&
            _lacks($_, 'tumblr_video_container')         &&
            _lacks($_, 'https://www.youtube.com/embed/')
         });
      },
   )->get
}

sub _lwn {
   my ($self, $commit) = @_;
   feed(
      'http://lwn.net/headlines/newrss',
      sub {
         shift->map(sub {
            $_->title($_->title =~ s/\[\$\]//r)
               if $_->title =~ m/\[\$\]/ &&
                  _do_req($_->link->href)->then_done(1)->else_done(0)->get;
            return $_
         })->grep(sub {
           $_->title !~ m/\[\$\]/ &&
           $_->title !~ m/security (?:updates|advisories)/i &&
           $_->title !~ m/stable kernel/i &&
           $_->title !~ m/kernel prepatch/i
         });
      },
      'LWN',
      $commit,
   )->get
}

sub _cpantesters {
   feed(
      'http://www.cpantesters.org/author/F/FREW-nopass.rss',
      sub {
         shift->grep(sub {
            $_->title !~ m(
               Pod-Weaver-Plugin-Ditaa |
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

sub _200_rss {
   [ 200, [ 'Content-type', 'application/atom+xml' ], [ $_[1]->as_xml ] ]
}

sub dispatch_request {
   my $s = shift;
   'GET + ?commit~' => sub {
     '/lwn'            => sub { $s->_200_rss($s->_lwn($_[1]))     },
     '/risingtensions' => sub { $s->_200_rss($s->_risingtensions) },
     '/badnrad'        => sub { $s->_200_rss($s->_badnrad)        },
     '/cpantesters'    => sub { $s->_200_rss($s->_cpantesters)    },
     '/chris'          => sub {
        my $err;
        my $res = try {
          _do_req('https://utcc.utoronto.ca/~cks/space/blog/?atom')
            ->get
        } catch {
          $err = $_;
        };

        return [
          500,
          [ 'Content-Type' => 'text/plain' ],
          [ $err->decoded_content ],
        ] if $err;

        [
          $res->code,
          [ 'Content-Type' => $res->header('content-type') ],
          [ $res->content ],
        ]
     },
     '/ok' => sub {
       [ 200, [ 'Content-Type', 'text/plain' ], [ "All is well\n\n" . `git rev-parse HEAD` ] ],
     },
  },
}

__PACKAGE__->run_if_script;
