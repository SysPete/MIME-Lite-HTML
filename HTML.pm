package MIME::Lite::HTML;

use LWP::UserAgent; 
use HTML::LinkExtor;
use URI::URL;
use MIME::Lite;
use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter);
@EXPORT = qw();
$VERSION = ('$Revision: 0.1 $ ' =~ /(\d+\.\d+)/)[0];

=head1 NAME

MIME::Lite::HTML: Provide routine to transform a HTML page in a MIME::Lite mail

=head1 SYNOPIS

  use MIME::Lite;
  use MIME::Lite::HTML;
  
  my $mailHTML = new MIME::Lite::HTML
  	From	=> 'MIME-Lite@alianwebserver.com',
	To  	=> 'alian@jupiter',
	Subject => 'Mail in HTML with images';
	
  $MIMEmail = $mailHTML->parse('http://www.alianwebserver.com/informatique/default.htm');
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

$Revision: 0.1 $

=head1 METHODS

=head2 new(%hash)

Create a new instance of MIME::Lite::HTML. 

%hash have this key : From, To, Subject, [Proxy], [Debug]

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
	if (!$res->is_success) {}
	else {$gabarit = $res->content;}
	# Include external CSS files
	$gabarit = $self->include_css($gabarit,$res->base);
	# Include external Javascript files
	$gabarit = $self->include_javascript($gabarit,$res->base);
	# Get all images and create part for each of them
	my $analyseur = HTML::LinkExtor->new;
	$analyseur->parse($gabarit);
	my @l = $analyseur->links;	
	my %images_read;
	foreach my $url (@l) 
		{
		my $urlAbs = URI::WithBase->new($$url[2],$res->base)->abs;
		# Replace href found to absolute one
		if ( ($$url[0] eq 'a') && ($$url[1] eq 'href') )
			{
			$gabarit=~s/$$url[2]/$urlAbs/gm;
			print "Replace ", $$url[2]," with ",$urlAbs,"\n" if $self->{_DEBUG};
			}		
		# Get only new <img src>
		next if (($$url[0] ne 'img') && ($$url[0] ne 'src') || ($images_read{$urlAbs}) );
		# Create MIME type
		if (lc($urlAbs)=~/gif$/) {$type = "image/gif";}
		else {$type = "image/jpg";}		
		# Get image
		print "Get ", $urlAbs,"\n" if $self->{_DEBUG};
		$images_read{$urlAbs}=1;
		my $res2 = $self->{_AGENT}->request(new HTTP::Request('GET' => $urlAbs));
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
	$gabarit=~s/<img([^"<>]*)src="([^">]*)"/pattern_image($1,$2,$res->base)/ieg;
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
	my $css = qr/(.*?)<link.*?href=["']?(.*?\.css)["']?[^>]*>(.*)/msi;
	while ($gabarit=~$css) 
		{
		my ($debut,$sty,$fin) = ($1,$2,$3);		
		my $ur = URI::URL->new($sty,$root);
		print "Include CSS file ",$ur->abs,"\n" if $self->{_DEBUG};
		my $res2 = $self->{_AGENT}->request(new HTTP::Request('GET' => $ur->abs));
		$gabarit=$debut."\n"."<!-- ".$ur->abs." -->\n".
			'<style type="text/css">'."\n".
			'<!--'."\n".$res2->content.
			"\n-->\n</style>\n".$fin;		
		}
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
	my $js = qr/(.*?)<script.*?src=["']?(.*?\.js)["']?[^>]*>.*?<\/script>(.*)/msi;
	while ($gabarit=~$js) 
		{
		my ($debut,$sty,$fin) = ($1,$2,$3);				
		my $ur = URI::URL->new($sty, $root);
		print "Include Javascript file ",$ur->abs,"\n" if $self->{_DEBUG};
		my $res2 = $self->{_AGENT}->request(new HTTP::Request('GET' => $ur->abs));
		$sty=URI::URL->new($sty, $res2->base)->abs;
		$gabarit=$debut."\n"."<!-- $sty -->\n".
			'<script language="Javascript" type="text/javascript">'."\n".
			'<!--'."\n".$res2->content.
			"\n-->\n</script>\n".$fin;		
		}
	return $gabarit;
	}

=head1 AUTHOR

Alain BARBET alian@alianwebserver.com

=cut
