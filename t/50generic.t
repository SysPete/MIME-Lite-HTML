#!/usr/bin/env perl -w

use strict;
use Test::More;
use MIME::Lite;
use MIME::Lite::HTML;
use Cwd;

my $t = "/var/tmp/mime-lite-html-tests";
my $p = cwd;
my $o = 1;
$o=(system("ln -s $p/t $t")==0);
my @files_to_test = glob("$t/docs/*.html");
if ($ARGV[0] && $ARGV[0] ne 'all') {
  undef @files_to_test; 
  push(@files_to_test, $ARGV[0]); 
}
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
     Debug    => ($ARGV[0] ? 1 : 0)
     );
  my $url_file = "file://$f";
  print $url_file,"\n";
  my $rep = 
    $mailHTML->parse($url_file, undef, ($ARGV[1]|| undef))->as_string;
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
  elsif ($f eq $ARGV[0]) {
    ok(open(F,">$ref"),"Create $ref");
    print F $rep;
    close(F);
    }
  elsif ($ARGV[0] && $ARGV[0] eq 'all') {
    ok(open(F,">$ref"),"Create $ref");
    print F $rep;
    close(F);
    }
}

unlink($t);
