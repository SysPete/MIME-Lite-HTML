#!/usr/bin/perl

  use MIME::Lite;
  use MIME::Lite::HTML;

  my $mailHTML = new MIME::Lite::HTML
       From     => 'alian@big-bang.alian.fr',
     To       => 'alian@jupiter.alian.fr',
     Subject => 'Mail in HTML with images';

  $MIMEmail = $mailHTML->parse('http://jupiter/',"et alors ?");
  print "Taille:",$mailHTML->size(),"\n"; 
  $MIMEmail->send; # or for win user : $mail->send_by_smtp('smtp.fai.com');
