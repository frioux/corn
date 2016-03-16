from feedpipe import FeedPipe
import inspect
import re
import datetime

def lambda_handler(event, context):
    operation = event['operation']

    try:
        func = inspect.getmembers(
            Corn,
            lambda x: inspect.ismethod(x) and x.__name__ == operation
        )[0][1]
    except IndexError:
        raise ValueError('Unrecognized operation "{}"'.format(operation))

    return func(Corn(), event['payload'])

class Corn:

    def _feed(self, url):
        return FeedPipe() \
            .cat([url]) \
            .grep(lambda e: e.published.text >
                  (datetime.datetime.now() -
                   datetime.timedelta(30)).strftime('%FT%T%Z') )

    def _content_lacks(self, entry, lack):
        return all( x not in unicode(entry.content)
            for x in lack)

    def _title_lacks(self, entry, lack):
        return all( x not in unicode(entry.title)
            for x in lack)

    def risingtensions(self, ignore):
        return self._feed('http://risingtensions.tumblr.com/rss') \
            .grep(lambda e:
                self._title_lacks(e, [ 'Audio', 'Video' ]) and
                self._content_lacks(e, [
                    'http://www.tumblr.com/video/',
                    'https://w.soundcloud.com',
                    'tumblr_video_container',
                    'https://www.youtube.com/embed/'])
             ).as_xml()

    def badnrad(self, ignore):
        return self._feed('http://badnrad.tumblr.com/rss') \
            .grep(lambda e:
                self._title_lacks(e, [ 'Audio', 'Video' ]) and
                self._content_lacks(e, [
                    'http://www.tumblr.com/video/',
                    'https://w.soundcloud.com',
                    'tumblr_video_container',
                    'https://www.youtube.com/embed/'])
             ).as_xml()

    def lwn(self, write):
        return self._feed('http://lwn.net/headlines/newrss') \
            .grep(lambda e:
                '[$]' not in unicode(e.title) and
                not re.search(
                    'security (?:updates|advisories)|stable kernel|kernel prepatch',
                    unicode(e.title),
                    re.IGNORECASE
                )
            ).as_xml()

    def cpantesters(self, ignore):
        return self._feed('http://www.cpantesters.org/author/F/FREW-nopass.rss') \
            .grep(lambda e:
                self._title_lacks(e, [x for x in """
Pod-Weaver-Plugin-Ditaa
DBIx-Class-Journal
DBIx-Class-Helpers-2.013002
Jemplate
DBIx-Class-DigestColumns
Web-Simple
SQL-Translator
SQL-Abstract-1.73
DBIx-Class-0.08207
Test-EOL
DBIx-Class-MaterializedPath
                """.split("\n") if len(x)]
                )
            ).as_xml()

if __name__ == '__main__':
    import sys
    print(lambda_handler({ 'operation': sys.argv[1], 'payload': sys.argv[2] }, {}))
