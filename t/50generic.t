#!/usr/bin/env perl -w

use strict;
use Test::More;
use MIME::Lite;
use MIME::Lite::HTML;
use Cwd;

my $t = "/var/tmp/mime-lite-html-tests";
my $p = cwd;
my $o = (system("ln -s $p/t $t")==0);
my @files_to_test = glob("$t/docs/*.html");
if ($o) {  plan tests => $#files_to_test+1; }
else { plan skip_all => "Error on link ".$p."/t!"; }
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
  print $url_file,"\n";
  my $rep = 
    $mailHTML->parse($url_file)->as_string;
  $rep =~s/^Date: .*$//gm;
  my $ib = 'Content-Type: multipart/related; boundary';
  if ($rep=~m!^$ib="(.*)"!m) {
    my $boundary = $1;
    my $mb = "alian-mime-lite-html";
    $rep=~s/$boundary/--$mb/gm;
  }
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
