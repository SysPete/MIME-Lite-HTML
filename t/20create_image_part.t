#!/usr/bin/env perl -w

use strict;
use Test::More;
use MIME::Lite;
use MIME::Lite::HTML;
use Cwd;

my $t = "/var/tmp/mime-lite-html-tests";
my $p = cwd;
my $o = (system("ln -s $p/t $t")==0);
my @files_to_test = glob("$t/docs/img/*.gif");
plan tests => $#files_to_test+1;
foreach my $f (@files_to_test) {
  my $ref = $f;
  $ref=~s/\.html/\.eml/; $ref=~s/docs\//ref\//;
  my $mailHTML = new MIME::Lite::HTML
    (
     From     => 'MIME-Lite@alianwebserver.com',
     To       => 'MIME-Lite@alianwebserver.com',
     Subject  => 'Mail in HTML with images',
     Debug    => 0
     );
  my $url_file = "file://$f";
  my $rep = $mailHTML->create_image_part($url_file);
  $rep = $rep->as_string;
  $rep =~s/^Date: .*$//gm;
  if (!$ARGV[0]) {
    open(PROD,">$f.created_by_test")
      or die "Can't create $f.created_by_test:$!";
    print PROD $rep;
    close(PROD);
    my $r = `diff $ref $f.created_by_test`;
    is($r, "", $ref);
    unlink("$f.created_by_test");
  }
  else {
    print "Create $ref\n";
    open(F,">$ref") or die "Can't create $ref:$!\n";
    print F $rep;
    close(F);
    }
}

unlink($t);
