package MIME::Lite::HTML;

# module MIME::Lite::HTML : Provide routine to transform a HTML page in 
# a MIME::Lite mail
# Copyright 2000 A.Barbet alian@alianwebserver.com.  All rights reserved.

# $Log: HTML.pm,v $
# Revision 0.5  2000/11/13 21:36:58  Administrateur
# - Arg, forgot cariage return in fill_template :-(
#
# Revision 0.4  2000/11/12 18:52:56  Administrateur
# - Add feature of replace word in gabarit (for newsletter by example)
# - Include body background
#
# Revision 0.3  2000/10/26 22:55:46  Administrateur
# Add parsing for form (action and input image)
#
# Revision 0.2  2000/10/26 20:08:06  Administrateur
# Update remplacement of relative url

use LWP::UserAgent; 
use HTML::LinkExtor;
use URI::URL;
use MIME::Lite;
use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter);
@EXPORT = qw();
$VERSION = ('$Revision: 0.5 $ ' =~ /(\d+\.\d+)/)[0];

=head1 NAME

MIME::Lite::HTML - Provide routine to transform a HTML page in a MIME-Lite mail

=head1 SYNOPSIS

  use MIME::Lite;
  use MIME::Lite::HTML;
  
  my $mailHTML = new MIME::Lite::HTML
  	From	=> 'MIME-Lite@alianwebserver.com',
	To  	=> 'alian@jupiter',
	Subject => 'Mail in HTML with images';
	
  $MIMEmail = $mailHTML->parse('http://www.alianwebserver.com');
  $MIMEmail->send; # or for win user : $mail->send_by_smtp('smtp.fai.com');

=head1 DESCRIPTION

This module provide routine to transform a HTML page in MIME::Lite mail. 
The job done is:

 + Get the file (LWP)
 + Parse page to find include images
 + Attach them to mail with adequat cid
 + Include external CSS,Javascript file
 + Replace relative url with absolute one

It can be used by example in a HTML newsletter. You make a classic HTML page, 
and give just url to MIME::Lite::HTML.

=head1 VERSION

$Revision: 0.5 $

=head1 METHODS

=head2 new(%hash)

Create a new instance of MIME::Lite::HTML. 

%hash have this key : From, To, Subject, [Proxy], [Debug], [HashTemplate]

$hash{'HashTemplate'} is a hash too. If present, MIME::Lite::HTML will 
substitute <? $name ?> with $hash{'HashTemplate'}{'name'} when parse url to
send.

=cut

sub new {
        my $class = shift;
        my $self = {};
        bless $self, $class;     
        my %param = @_;
        my $mail = new MIME::Lite 
		From	=> $param{'From'},
		To  	=> $param{'To'},
		Subject => $param{'Subject'},
		Type	=> 'multipart/related';
        $self->{_MAIL} = $mail;
        $self->{_DEBUG} = 1 if $param{'Debug'};
	print "Set proxy for http : ", $param{'Proxy'},"\n" if ($self->{_DEBUG} && $param{'Proxy'});
	$self->{_AGENT} = new LWP::UserAgent 'MIME-Lite', 'alian@alianwebserver.com';
	$self->{_AGENT}->proxy('http',$param{'Proxy'}) if $param{'Proxy'};
	$self->{_HASH_TEMPLATE}= $param{'HashTemplate'} if $param{'HashTemplate'};
        return $self;
    	}

=head2 parse($url)

Subroutine used for created HTML mail with MIME-Lite

 $url   : Url to file to parse. Can be a local file. 

Return the MIME::Lite part to send

=cut

sub parse
	{	
	my($self,$url_page)=@_;
	my ($type,@mail,$gabarit);
	# Get content of $url_page with LWP
	print "Get ", $url_page,"\n" if $self->{_DEBUG};
	my $req = new HTTP::Request('GET' => $url_page);
	my $res = $self->{_AGENT}->request($req);
	if (!$res->is_success) {die "$url_page n'est pas accessible";}
	else {$gabarit = $res->content;}
	# Get all images and create part for each of them
	my $analyseur = HTML::LinkExtor->new;
	$analyseur->parse($gabarit);
	my @l = $analyseur->links;	
	# Include external CSS files
	$gabarit = $self->include_css($gabarit,$res->base);
	# Include external Javascript files
	$gabarit = $self->include_javascript($gabarit,$res->base);
	($gabarit,@mail) = $self->input_image($gabarit,$res->base);
	$gabarit = $self->link_form($gabarit,$res->base);
	my (%images_read,%url_remplace);
	foreach my $url (@l) 
		{#print @$url,"\n";
		my $urlAbs = URI::WithBase->new($$url[2],$res->base)->abs;
		# Replace relative href found to absolute one
		if ( ($$url[0] eq 'a') 
		  && ($$url[1] eq 'href') 
		  && ($$url[2]!~m!^http://!)
		  && (!$url_remplace{$urlAbs}) )
			{
			$gabarit=~s/href="?'?$$url[2]("?|'?)/href="$urlAbs"/gim;
			print "Replace ", $$url[2]," with ",$urlAbs,"\n" if $self->{_DEBUG};
			$url_remplace{$urlAbs}=1;
			}		
		elsif (($$url[0] eq 'body') && ($$url[1] eq 'background'))
			{
			$gabarit=~s/background="?'?$$url[2]("?|'?)/background="cid:$urlAbs"/gim;
			print "Get ", $urlAbs,"\n" if $self->{_DEBUG};
			my $res2 = $self->{_AGENT}->request(new HTTP::Request('GET' => $urlAbs));
			# Create MIME type
			if (lc($urlAbs)=~/gif$/) {$type = "image/gif";}
			else {$type = "image/jpg";}		
			# Create part
			my $mail = new MIME::Lite 
				Data => $res2->content,
				Encoding =>'base64';		
			$mail->attr("Content-type"=>$type);
			$mail->attr('Content-ID'=>$urlAbs);
			push(@mail,$mail);
			}
		# Get only new <img src>
		next if ((lc($$url[0]) ne 'img') 
		      && (lc($$url[0]) ne 'src') 
		      || ($images_read{$urlAbs}) );
		# Create MIME type
		if (lc($urlAbs)=~/gif$/) {$type = "image/gif";}
		else {$type = "image/jpg";}		
		# Get image
		print "Get ", $urlAbs,"\n" if $self->{_DEBUG};
		$images_read{$urlAbs}=1;
		my $res2 = $self->{_AGENT}->request(new HTTP::Request('GET' => $urlAbs));
		if (!$res2->is_success) {print "Attention:$urlAbs n'est pas accessible";}
		# Create part
		my $mail = new MIME::Lite 
			Data => $res2->content,
			Encoding =>'base64';		
		$mail->attr("Content-type"=>$type);
		$mail->attr('Content-ID'=>$urlAbs);
		push(@mail,$mail);
		}
	# Replace in HTML link with image with cid:key
	sub pattern_image {return '<img '.$_[0].'src="cid:'.URI::WithBase->new($_[1],$_[2])->abs.'"';}
	$gabarit=~s/<img([^<>]*)src=(["']?)([^"'> ]*)(["']?)/pattern_image($1,$3,$res->base)/ieg;
	# Substitue value in template if needed
	if ($self->{_HASH_TEMPLATE}) {$gabarit=$self->fill_template($gabarit,$self->{_HASH_TEMPLATE});}
	# Create part for HTML
	my $part = new MIME::Lite 
		'Type' 	=>'TEXT',   
		'Data' 	=>$gabarit;
	$part->attr("content-type"=> "text/html; charset=iso-8859-1");
	# Push HTML part on first
	unshift(@mail,$part);
	# Return list of part
	foreach (@mail) {$self->{_MAIL}->attach($_);}
	return $self->{_MAIL};
	}

=head2 include_css($gabarit,$root) 

(private)

Search in HTML buffer ($gabarit) to remplace call to extern CSS file
with his content. $root is original absolute url where css file will
be found.

=cut 

sub include_css
	{	
	my ($self,$gabarit,$root)=@_;
	sub pattern_css
		{
		my ($self,$url,$milieu,$fin,$root)=@_;
		my $ur = URI::URL->new($url, $root)->abs;
		print "Include CSS file $ur\n" if $self->{_DEBUG};
		my $res2 = $self->{_AGENT}->request(new HTTP::Request('GET' => $ur));
		print "Ok file downloaded\n" if $self->{_DEBUG};
		return 	'<style type="text/css">'."\n".
			'<!--'."\n".$res2->content.
			"\n-->\n</style>\n";
		}
	$gabarit=~s/<link([^<>]*?)href="?([^" ]*css)"?([^>]*)>/$self->pattern_css($2,$1,$3,$root)/iegm;	
	print "Done CSS\n" if $self->{_DEBUG};
	return $gabarit;
	}

=head2 include_javascript($gabarit,$root) 

(private)

Search in HTML buffer ($gabarit) to remplace call to extern javascript file
with his content. $root is original absolute url where javascript file will
be found.

=cut

sub include_javascript
	{
	my ($self,$gabarit,$root)=@_;
	sub pattern_js
		{
		my ($self,$url,$milieu,$fin,$root)=@_;
		my $ur = URI::URL->new($url, $root)->abs;
		print "Include Javascript file $ur\n" if $self->{_DEBUG};
		my $res2 = $self->{_AGENT}->request(new HTTP::Request('GET' => $ur));
		my $content = $res2->content;
		print "Ok file downloaded\n" if $self->{_DEBUG};
		return "\n"."<!-- $ur -->\n".
			'<script '.$milieu.$fin.">\n".
			'<!--'."\n".$content.
			"\n-->\n</script>\n";
		}
	$gabarit=~s/<script([^>]*)src="?([^" ]*js)"?([^>]*)>/$self->pattern_js($2,$1,$3,$root)/iegm;	
	print "Done Javascript\n" if $self->{_DEBUG};
	return $gabarit;
	}


=head2 input_image($gabarit,$root) 

(private)

Search in HTML buffer ($gabarit) to remplace input form image with his cid

Return final buffer and list of MIME::Lite part

=cut

sub input_image
	{
	my ($self,$gabarit,$root)=@_;	
	my @mail;
	sub pattern_input_image
		{
		my ($self,$deb,$url,$fin,$base,$ref_tab_mail)=@_;
		my $type;
		my $ur = URI::URL->new($url, $base)->abs;
		# Create MIME type
		if (lc($ur)=~/gif$/) {$type="image/gif";}
		else {$type = "image/jpg";}		
		my $res = $self->{_AGENT}->request(new HTTP::Request('GET' => $ur));
		# Create part
		my $mail = new MIME::Lite 
			Data => $res->content,
			Encoding =>'base64';		
		$mail->attr("Content-type"=>$type);
		$mail->attr('Content-ID'=>$ur);	
		push(@$ref_tab_mail,$mail);
		return '<input '.$deb.' src="cid:'.$ur.'"'.$fin;
		}
	$gabarit=~s/<input([^<>]*)src="?([^"'> ]*)"?([^>]*)>/$self->pattern_input_image($1,$2,$3,$root,\@mail)/iegm;
	print "Done input image\n" if $self->{_DEBUG};
	return ($gabarit,@mail);
	}


=head2 link_form($gabarit,$root) 

(private)

Replace link to formulaire with absolute link

=cut

sub link_form
	{
	my ($self,$gabarit,$root)=@_;	
	my @mail;
	sub pattern_link_form
		{
		my ($self,$deb,$url,$fin,$base)=@_;
		my $type;
		my $ur = URI::URL->new($url, $base)->abs;
		return '<form '.$deb.' action="'.$ur.'"'.$fin.'>';
		}
	$gabarit=~s/<form([^<>]*)action="?([^"'> ]*)"?([^>]*)>/$self->pattern_link_form($1,$2,$3,$root)/iegm;
	print "Done form\n" if $self->{_DEBUG};
	return $gabarit;
	}

=head2 fill_template($masque,$vars)

 $masque : Chemin du template
 $vars : hash des noms/valeurs à substituer dans le template

Rend le template avec ses variables substituées.
Ex: si $$vars{age}=12, et que le fichier $masque contient la chaine:

  J'ai <? $age ?> ans, 

la fonction rendra

  J'ai 12 ans,

=cut

sub fill_template
	{
	my ($self,$masque,$vars)=@_;
	my @buf=split(/\n/,$masque);
	my $i=0;
	while (my ($n,$v)=each(%$vars)) 
		{
		if ($v) {map {s/<\?\s\$$n\s\?>/$v/gm} @buf;}
		else {map {s/<\?\s\$$n\s\?>//gm} @buf;}
		$i++;		
		}
	print "<b>Attention</b>: pas de variables à substituer dans $masque<br>\n" if ($i==0);
	return join("\n",@buf);
	}
	
=head1 AUTHOR

Alain BARBET alian@alianwebserver.com

=cut
