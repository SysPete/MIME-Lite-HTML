package MIME::Lite::HTML;

# module MIME::Lite::HTML : Provide routine to transform a HTML page in 
# a MIME::Lite mail
# Copyright 2001 A.Barbet alian@alianwebserver.com.  All rights reserved.

# $Log: HTML.pm,v $
# Revision 1.3  2001/05/05 22:18:10  alian
# - Add feature of  IncludeImage key in constructor: now module can use
# "Content-Location" field, "Content-CID field" or not include images and 
# only make an absolute link.
# - New construction of MIME message: module send multipart only if needed
# - Correct an incorrect use of LWP-Agent constructor to avoid warning 
# messages(tks to StevenBenbow@quintessa.org)
# - Correct a strange error that occur with URI::http if i don't chomp url
# before call it (tks to Maarten Veerman <mtveerman@mindless.com>)
#
# Revision 1.2  2001/03/20 22:35:56  alian
# - Add lot of pod documentation
# - Change how final mail is build:
#  If no images are found when parse routine is used, this modules did'nt
#  use a multipart/related part, but a text/html part. Thus, we can reach
#  a max. of mail clients (See "clients tested" in documentation).
# - Add size function
#
# Revision 1.1  2001/03/04 22:29:07  alian
# - Correct an error with background image quote
#
# Revision 1.0  2001/03/04 22:13:19  alian
# - Correct major problem with Eudora (See Clients tested in documentation)
# - Build final MIME-Lite object with knowledge of RFC-2257
# - Add some POD documentation and references
#
# Revision 0.9  2001/02/02 01:15:35  alian
# Correct some other things with error handling 
# (suggested by Steve Harvey <sgh@vex.net>
#
# Revision 0.8  2001/01/21 00:58:48  alian
# Correct error function
#
# Revision 0.7  2000/12/30 20:22:27  alian
# - Allow to send a string of text to the parse function, instead of an url
# - Add feature to put data on the fly when image are available only on memory
# - Put comments on print when buffer find url
# Ideas suggested by mtveerman@mindless.com
#
# Revision 0.6  2000/12/13 11:02:58  alian
# - Allow sup parameter for MIME-Lite in constructor
# - Add parameter for parse url to include a text file when HTML
#    is not supported by client.
#
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
$VERSION = ('$Revision: 1.3 $ ' =~ /(\d+\.\d+)/)[0];

#------------------------------------------------------------------------------
# new
#------------------------------------------------------------------------------
sub new
  {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    my %param = @_;
    # Agent name
    $self->{_AGENT} = new LWP::UserAgent;
    $self->{_AGENT}->agent("MIME-Lite-HTML $VERSION");
    $self->{_AGENT}->from('mime-lite-html@alianwebserver.com' );
    # Set debug level
    if ($param{'Debug'})
      {
	$self->{_DEBUG} = 1;
	delete $param{'Debug'};
      }
    # Set type of include to do
    if ($param{'IncludeType'})
      {
	die "IncludeType must be in 'extern', 'cid' or 'location'\n" if
	  ( ($param{'IncludeType'} ne 'extern') and
	    ($param{'IncludeType'} ne 'cid') and
	    ($param{'IncludeType'} ne 'location'));	
	$self->{_include} = $param{'IncludeType'};
	delete $param{'IncludeType'};
      }
    # Defaut type: use a Content-Location field
    else {$self->{_include}='location';}

    # Set proxy to use to get file
    if ($param{'Proxy'})
      {
	$self->{_AGENT}->proxy('http',$param{'Proxy'}) ;
	print "Set proxy for http : ", $param{'Proxy'},"\n" 
	  if ($self->{_DEBUG});
	delete $param{'Proxy'};
      }
    # Set hash to use with template
    if ($param{'HashTemplate'})
      {
	$param{'HashTemplate'} = ref($param{'HashTemplate'}) eq "HASH" 
	  ? $param{'HashTemplate'} : %{$param{'HashTemplate'}};
	$self->{_HASH_TEMPLATE}= $param{'HashTemplate'};
	delete $param{'HashTemplate'};
      }
    $self->{_param} = \%param;
    # Ok I hope I known what I do ;-)
    MIME::Lite->quiet(1);
    return $self;
  }

#------------------------------------------------------------------------------
# parse
#------------------------------------------------------------------------------
sub parse
     {
     my($self,$url_page,$url_txt,$url1)=@_;
     my ($type,@mail,$gabarit,$gabarit_txt,$racinePage);

     if ($url_page=~/^(https?|ftp|file|nntp):\/\//)
        {
        # Get content of $url_page with LWP
        print "Get ", $url_page,"\n" if $self->{_DEBUG};	
        my $req = new HTTP::Request('GET' => $url_page);
        my $res = $self->{_AGENT}->request($req);
        if (!$res->is_success) 
	  {$self->set_err("Can't fetch $url_page (".$res->message.")");}
        else {$gabarit = $res->content;}
        $racinePage=$res->base;
        }
     else {$gabarit=$url_page;$racinePage=$url1;}

     # Get content of $url_txt with LWP if needed
     if ($url_txt)
          {
          if ($url_txt=~/^(https?|ftp|file|nntp):\/\//)
            {
            print "Get ", $url_txt,"\n" if $self->{_DEBUG};
            my $req2 = new HTTP::Request('GET' => $url_txt);
            my $res3 = $self->{_AGENT}->request($req2);
            if (!$res3->is_success) 
	      {$self->set_err("Can't fetch $url_txt (".$res3->message.")");}
            else {$gabarit_txt = $res3->content;}
            }
          else {$gabarit_txt=$url_txt;}
          }
     return if (!$gabarit);
     # Get all images and create part for each of them
     my $analyseur = HTML::LinkExtor->new;
     $analyseur->parse($gabarit);
     my @l = $analyseur->links;

     # Include external CSS files
     $gabarit = $self->include_css($gabarit,$racinePage);

     # Include external Javascript files
     $gabarit = $self->include_javascript($gabarit,$racinePage);
     ($gabarit,@mail) = $self->input_image($gabarit,$racinePage);
     $gabarit = $self->link_form($gabarit,$racinePage);
     my (%images_read,%url_remplace);
     # Scan each part found by linkExtor
     foreach my $url (@l)
       {#print @$url,"\n";
	 my $urlAbs = URI::WithBase->new($$url[2],$racinePage)->abs;
	 chomp $urlAbs; # Sometime a strange cr/lf occur
	 # Replace relative href found to absolute one
	 if ( ($$url[0] eq 'a')
	      && ($$url[1] eq 'href')
	      && ($$url[2]!~m!^http://!)
	      && (!$url_remplace{$urlAbs}) )
	   {
       	     $gabarit=~s/\s href= [\"']? $$url[2] [\"']?
                        /href="$urlAbs"/gimx;
	     print "Replace ", $$url[2]," with ",$urlAbs,"\n" 
	       if ($self->{_DEBUG});
	     $url_remplace{$urlAbs}=1;
           }
         # For images background
         elsif ($$url[1] eq 'background')
	   {
	     # Replace relative url with absolute
	     my $v;
	     if ($self->{_include} eq 'cid') 
	       {$v ="background=\"cid:$urlAbs\"";}
	     else {$v ="background=\"$urlAbs\"";}
	     $gabarit=~s/background=\"$$url[2]\"/$v/im;
	     # Exit with extern configuration, don't include image
	     next if ($self->{_include} eq 'extern');
	     print "Get ", $urlAbs,"\n" if $self->{_DEBUG};
	     my $res2 = $self->{_AGENT}->request
	       (new HTTP::Request('GET' => $urlAbs));
	     # Create MIME  type
	     if (lc($urlAbs)=~/gif$/) {$type = "image/gif";}
	     else {$type = "image/jpg";}
	     # Create part
	     my $mail = new MIME::Lite
	       Data => $res2->content,
	       Encoding =>'base64';
	     $mail->attr("Content-type"=>$type);
	     if ($self->{_cid}) {$mail->attr('Content-ID'=>$urlAbs);}
	     else {$mail->attr('Content-Location'=>$urlAbs);}
	     push(@mail,$mail);
	   }
	 # Get only new <img src>
	 # Exit with extern configuration, don't include image
	 next if ( ($self->{_include} eq 'extern') 
		   || ((lc($$url[0]) ne 'img') 
		       && (lc($$url[0]) ne 'src') 
		       || ($images_read{$urlAbs}) ));
	 # Create MIME type
	 if (lc($urlAbs)=~/gif$/) {$type = "image/gif";}
	 else {$type = "image/jpg";}
	 my $buff1;
	 # Url is already in memory
	 if ($self->{_HASH_TEMPLATE}{$urlAbs})
	   {
	     print "Using buffer on: ", $urlAbs,"\n" if $self->{_DEBUG};
	     $buff1 = ref($self->{_HASH_TEMPLATE}{$urlAbs}) eq "ARRAY" 
	       ? join "", @{$self->{_HASH_TEMPLATE}{$urlAbs}} 
	     : $self->{_HASH_TEMPLATE}{$urlAbs};
	     delete $self->{_HASH_TEMPLATE}{$urlAbs};
	   }
	 else # Get image
	   {
	     print "Get ", $urlAbs,"\n" if $self->{_DEBUG};
	     my $res2 = $self->{_AGENT}->
	       request(new HTTP::Request('GET' => $urlAbs));
	     if (!$res2->is_success) {$self->set_err("Can't get $urlAbs\n");}
	     $buff1=$res2->content;
	   }
	 # Create part
	 $images_read{$urlAbs}=1;
	 my $mail = new MIME::Lite
	   Data => $buff1,
	   Encoding =>'base64'; 
	 $mail->replace("X-Mailer" => "");
	 $mail->replace("MIME-Version" => "");
	 $mail->replace("Content-Disposition" => "");
	 $mail->attr("Content-type"=>$type);
	 # With cid configuration, add a Content-ID field
	 if ($self->{_include} eq 'cid') 
	   {$mail->attr('Content-ID' =>'<'.$urlAbs.'>');}
	 # Else (location) put a Content-Location field
	 else {$mail->attr('Content-Location'=>$urlAbs);}
	 push(@mail,$mail);
       }
     # Replace in HTML link with image with cid:key
     sub pattern_image_cid 
       {
	 return '<img '.$_[0].'src="cid:'.
	   URI::WithBase->new($_[1],$_[2])->abs.'"';
       }
     # Replace relative url for image with absolute
     sub pattern_image 
       {return '<img '.$_[0].'src="'.URI::WithBase->new($_[1],$_[2])->abs.'"';}
     
     # If cid choice, put a cid + absolute url on each link image
     if ($self->{_include} eq 'cid') 
       {$gabarit=~s/<img ([^<>]*) src= (["']?) ([^"'> ]* )(["']?)
	           /pattern_image_cid($1,$3,$racinePage)/iegx;}
     # Else just make a absolute url
     else {$gabarit=~s/<img ([^<>]*) src= (["']?)([^"'> ]*) (["']?)
	              /pattern_image($1,$3,$racinePage)/iegx;}
     
     # Substitue value in template if needed
     if (scalar keys %{$self->{_HASH_TEMPLATE}}!=0)
       {$gabarit=$self->fill_template($gabarit,$self->{_HASH_TEMPLATE});}
     
     # Create MIME-Lite object
     $self->build_mime_object($gabarit,$gabarit_txt,@mail);

     return $self->{_MAIL};
   }

#------------------------------------------------------------------------------
# size
#------------------------------------------------------------------------------
sub size
  {
  my ($self)=shift;
  return length($self->{_MAIL}->as_string);
  }


#------------------------------------------------------------------------------
# build_mime_object
#------------------------------------------------------------------------------
sub build_mime_object
  {
    my ($self,$html,$txt,@mail)=@_;
    my ($txt_part,$mail);
    # Create part for HTML
    my $part = new MIME::Lite
      'Type'      =>'TEXT',
      'Encoding'=>'quoted-printable',
      'Data'      =>$html;
    $part->attr("content-type"=> "text/html; charset=iso-8859-1");
    # Remove some header for Eudora client in HTML and related part
    $part->replace("MIME-Version" => "");
    $part->replace('X-Mailer' =>"");
    $part->replace('Content-Disposition' =>"");

    # Create part for text if needed
    if ($txt)
      {
	$txt_part = new MIME::Lite 
	  'Type'      => 'TEXT',  
	  'Encoding'  => '7bit', 
	  'Data'      => $txt;
	$txt_part->attr("content-type"=> "text/plain; charset=us-ascii");
	# Remove some header for Eudora client
	$txt_part->replace("MIME-Version" => "");
	$txt_part->replace("X-Mailer" => "");
	$txt_part->replace("Content-Disposition" => "");
      }
    
    # Set content type of main part
    # If only HTML part create a text/html part
    if (!$txt and !@mail)
      {
	$mail = new MIME::Lite (%$self->{_param}); 
	$mail->attr("content-type"=> "text/html");
	$mail->data($html);
      }
    # If images and html and no text, multipart/related
    elsif (@mail and !$txt)
      {
	my $ref=$self->{_param};
	$$ref{'Type'} = "multipart/related";	
	$mail = new MIME::Lite (%$ref);
	# Attach HTML part to related part
	$mail->attach($part);
	# Attach each image to related part
	foreach (@mail) {$mail->attach($_);} # Attach list of part
	#$mail->replace("MIME-Version" => "");
	$mail->replace("Content-Disposition" => "");
      }
    # Else if html and text and no images, multipart/alternative
    elsif ($txt and !@mail)
      {
	my $ref=$self->{_param};
	$$ref{'Type'} = "multipart/alternative";	
	$mail = new MIME::Lite (%$ref);
	$mail->attach($txt_part); # Attach text part
	$mail->attach($part); # Attach HTML part	
      }
    # Else (html, txt and images) mutilpart/alternative
    else
      {
	my $ref=$self->{_param};
	$$ref{'Type'} = "multipart/alternative";	
	$mail = new MIME::Lite (%$ref); 
	# Create related part
 	my $rel = new MIME::Lite ('Type'=>'multipart/related');
	$rel->replace("Content-transfer-encoding" => "");
	$rel->replace("MIME-Version" => "");
	$rel->replace("X-Mailer" => "");
	# Attach text part to alternative part
	$mail->attach($txt_part);
	# Attach HTML part to related part
	$rel->attach($part);
	# Attach each image to related part
	foreach (@mail) {$rel->attach($_);}
	# Attach related part to alternative part
	$mail->attach($rel);
      }
    $mail->replace('X-Mailer',"MIME::Lite::HTML $VERSION");
    $self->{_MAIL} = $mail;
  }

#------------------------------------------------------------------------------
# include_css
#------------------------------------------------------------------------------
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
	return      '<style type="text/css">'."\n".
	  '<!--'."\n".$res2->content.
	    "\n-->\n</style>\n";
      }
    $gabarit=~s/<link([^<>]*?)href="?([^\" ]*css)"?([^>]*)>
      /$self->pattern_css($2,$1,$3,$root)/iegmx;
    print "Done CSS\n" if ($self->{_DEBUG});
    return $gabarit;
  }


#------------------------------------------------------------------------------
# include_javascript
#------------------------------------------------------------------------------
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
    $gabarit=~s/<script([^>]*)src="?([^\" ]*js)"?([^>]*)>
      /$self->pattern_js($2,$1,$3,$root)/iegmx;
    print "Done Javascript\n" if $self->{_DEBUG};
    return $gabarit;
  }


#------------------------------------------------------------------------------
# input_image
#------------------------------------------------------------------------------
sub input_image
  {
    my ($self,$gabarit,$root)=@_;
    my @mail;
    sub pattern_input_image
      {
	my ($self,$deb,$url,$fin,$base,$ref_tab_mail)=@_;
	my $ur = URI::URL->new($url, $base)->abs;
	if ($self->{_include} ne 'extern')
	  {push(@$ref_tab_mail,$self->create_image_part($ur));}
	if ($self->{_include} eq 'cid') 
	  {return '<input '.$deb.' src="cid:'.$ur.'"'.$fin;}
	else {return '<input '.$deb.' src="'.$ur.'"'.$fin;}
      }
    $gabarit=~s/<input([^<>]*)src="?([^\"'> ]*)"?([^>]*)>
               /$self->pattern_input_image($1,$2,$3,$root,\@mail)/iegmx;
    print "Done input image\n" if $self->{_DEBUG};
    return ($gabarit,@mail);
  }

#------------------------------------------------------------------------------
# create_image_part
#------------------------------------------------------------------------------
sub create_image_part
  {
    my ($self,$ur)=@_;
    my $type;
    # Create MIME type
    if (lc($ur)=~/gif$/) {$type="image/gif";}
    else {$type = "image/jpg";}
    my $res = $self->{_AGENT}->request
      (new HTTP::Request('GET' => $ur));
    # Create part
    my $mail = new MIME::Lite
	      Data => $res->content,
      Encoding =>'base64';
    $mail->attr("Content-type"=>$type);
    # With cid configuration, add a Content-ID field
    if ($self->{_include} eq 'cid') 
      {$mail->attr('Content-ID' =>'<'.$ur.'>');}
    # Else (location) put a Content-Location field
    else {$mail->attr('Content-Location'=>$ur);}
    $mail->replace("X-Mailer" => "");
    $mail->replace("MIME-Version" => "");
    $mail->replace("Content-Disposition" => "");
    return $mail;
  }

#------------------------------------------------------------------------------
# link_form
#------------------------------------------------------------------------------
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
     $gabarit=~s/<form([^<>]*)action="?([^\"'> ]*)"?([^>]*)>
                /$self->pattern_link_form($1,$2,$3,$root)/iegmx;
    print "Done form\n" if $self->{_DEBUG};
    return $gabarit;
  }

#------------------------------------------------------------------------------
# fill_template
#------------------------------------------------------------------------------
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
    return join("\n",@buf);
     }

#------------------------------------------------------------------------------
# set_err
#------------------------------------------------------------------------------
sub set_err 
  {
    my($self,$error) = @_;
    print $error,"\n" if ($self->{_DEBUG});
    my @array = @{$self->{_ERRORS}} if ($self->{_ERRORS});
    push @array, $error;
    $self->{_ERRORS} = \@array;
    return 1;    
  }

#------------------------------------------------------------------------------
# errstr 
#------------------------------------------------------------------------------
sub errstr 
  {
    my($self) = @_;
    return @{$self->{_ERRORS}} if ($self->{_ERRORS});
    return ();
  }


#------------------------------------------------------------------------------
# POD Documentation
#------------------------------------------------------------------------------

=head1 NAME

MIME::Lite::HTML - Provide routine to transform a HTML page in a MIME-Lite mail

=head1 SYNOPSIS
  
  use MIME::Lite::HTML;

  my $mailHTML = new MIME::Lite::HTML
     From     => 'MIME-Lite@alianwebserver.com',
     To       => 'alian@saturne',
     Subject => 'Mail in HTML with images';

  $MIMEmail = $mailHTML->parse('http://www.alianwebserver.com');
  $MIMEmail->send; # or for win user : $mail->send_by_smtp('smtp.fai.com');

=head1 VERSION

$Revision: 1.3 $

=head1 DESCRIPTION

This module is a Perl mail client interface for sending message that 
support HTML format and build them for you..
This module provide routine to transform a HTML page in MIME::Lite mail.
So you need this module to use MIME-Lite-HTML possibilities

=head2 What's happen ?

The job done is:

=over

=item *

Get the file (LWP) if needed

=item *

Parse page to find include images

=item *

Attach them to mail with adequat header if asked (default)

=item *

Include external CSS,Javascript file

=item *

Replace relative url with absolute one

=item *

Build the final MIME-Lite object with each part found

=back

=head2 Usage

Did you alread see link like "Send this page to a friend" ?. With this module,
you can do script that to this in 3 lines.

It can be used too in a HTML newsletter. You make a classic HTML page,
and give just url to MIME::Lite::HTML.

=head2 Construction

MIME-Lite-HTML use a MIME-Lite object, and RFC2257 construction:

If images and text are present, construction use is:

  --> multipart/alternative
  ------> text/plain
  ------> multipart/related
  -------------> text/html
  -------------> each images

If no images but text is present, this is that:

  ---> multipart/alternative
  -------> text/plain if present
  -------> text/html

If images but no text, this is:

  ---> multipart/related
  -------> text/html
  -------> each images

If no images and no text, this is:

  ---> text/html


=head2 Documentation

Additionnal documentation can be found here:

=over

=item *

MIME-lite module

=item *

RFC 822, RFC 1521, RFC 1522 and specially RFC 2257 (MIME Encapsulation
of Aggregate Documents, such as HTML)

=back

=head2 Clients tested

HTML in mail is not full supported so this module can't work with all email
clients. If some client recognize HTML, they didn't support images include in
HTML. So in fact, they recognize multipart/relative but not multipart/related.

=over

=item Netscape Messager (Linux-Windows)

100% ok

=item Outlook Express (Windows-Mac)

100% ok. Mac work only with Content-Location header. Thx to Steve Benbow for
give mr this feedback and for his test.

=item Eudora (Windows)

If this module just send HTML and text, (without images), 100% ok.

With images, Eudora didn't recognize multipart/related part as describe in
RFC 2257 even if he can read his own HTML mail. So if images are present in 
HTML part, text and HTML part will be displayed both, text part in first. 
Two additional headers will be displayed in HTML part too in this case. 
Version 1.0 of this module correct major problem of headers displayed 
with image include in HTML part.

=item KMail (Linux)

If this module just send HTML and text, (without images), 100% ok.

In other case, Kmail didn't support image include in HTML. So if you set in 
KMail "Prefer HTML to text", it display HTML with images broken. Otherwise, 
it display text part.

=item Pegasus (Windows)

If this module just send HTML and text, (without images), 100% ok.

Pegasus didn't support images in HTML. When it find a multipart/related 
message, it ignore it, and display text part.

=back

If you find others mail client who support (or not support) MIME-Lite-HTML
module, give me some feedback ! If you want be sure that your mail can be 
read by maximum of people, (so not only OE and Netscape), don't include 
images in your mail, and use a text buffer too. If multipart/related mail 
is not recognize, multipart/alternative can be read by the most of mail client.

=head1 Public Interface

=over

=item new(%hash)

Create a new instance of MIME::Lite::HTML.

The hash can have this key : [Proxy], [Debug], [IncludeType], [HashTemplate]

Proxy is url of proxy to use. Ex: 'Proxy' => 'http://192.168.100.166:8080'

Debug is trace to stdout during parsing. Ex: 'Debug' => 1 

IncludeType is method to use when finding images:

=over

=item location

Default method is embed them in mail whith 'Content-Location' header. 

=item cid

You use a 'Content-CID' header. 

=item extern

Images are not embed, relative url are just replace with absolute, 
so images are fetch when user read mail. (Server must be reachable !)

=back

$hash{'HashTemplate'} is a reference to a hash. If present, MIME::Lite::HTML 
will substitute <? $name ?> with $hash{'HashTemplate'}{'name'} when parse url 
to send. $hash{'HashTemplate'} can be used too for include data for subelement.
Ex:
$hash{'HashTemplate'}{'http://www.al.com/images/sommaire.gif'}=\@data;
or $hash{'HashTemplate'}{'http://www.al.com/script.js'}="alert("Hello world");;

When module find the image http://www.alianwebserver.com/images/sommaire.gif 
in buffer, it don't get image with LWP but use data found in 
$hash{'HashTemplate'}.

Others keys are use with MIME::Lite constructor.

This MIME-Lite keys are: Bcc, Encrypted, Received, Sender, Cc, From,
References, Subject, Comments, Keywords, Reply-To To, Content-*,
Message-ID,Resent-*, X-*,Date,MIME-Version,Return-Path,
Organization

=item parse($html, [$url_txt], [$url_base])

Subroutine used for created HTML mail with MIME-Lite

Parameters:

=over

=item $html

Url of HTML file to send, can be a local file. If $url is not an
url (http or https or ftp or file or nntp), $url is used as a buffer.
Example : http://www.alianwebserver.com, file://c|/tmp/index.html
or '<img src=toto.gif>'.

=item $url_txt

Url of text part to send for person who doesn't support HTML mail.
As $html, $url_txt can be a simple buffer.

=item $url_base

$url_base is used if $html is a buffer, for get element found in HTML buffer.

=back

Return the MIME::Lite part to send

=item size()

Display size of mail in characters (so octets) that will be send.
(So use it *after* parse method). Use this method for control
size of mail send, I personnaly hate receive 500k by mail.
I pay for a 33k modem :-(

=back

=head1 Private methods

=over

=item build_mime_object($html,[$txt],[@mail])

(private)

Build the final MIME-Lite object to send with each part read before

=over

=item $html

Buffer of HTML part

=item $txt

Buffer of text part

=item @mail

List of images attached to HTML part. Each item is a MIME-Lite object.

=back

See "Construction" in "Description" for know how MIME-Lite object is build.

=item include_css($gabarit,$root)

(private)

Search in HTML buffer ($gabarit) to remplace call to extern CSS file
with his content. $root is original absolute url where css file will
be found.

=item include_javascript($gabarit,$root)

(private)

Search in HTML buffer ($gabarit) to remplace call to extern javascript file
with his content. $root is original absolute url where javascript file will
be found.

=item input_image($gabarit,$root)

(private)

Search in HTML buffer ($gabarit) to remplace input form image with his cid

Return final buffer and list of MIME::Lite part

=item link_form($gabarit,$root)

(private)

Replace link to formulaire with absolute link

=item fill_template($masque,$vars)

 $masque : Path of template
 $vars : hash ref with keys/val to substitue

Give template with remplaced variables
Ex: if $$vars{age}=12, and $masque have

  J'ai <? $age ?> ans,

this function give:

  J'ai 12 ans,

=back

=head1 Error Handling

The set_err routine is used privately. You can ask for an array of all the 
errors which occured inside the parse routine by calling:

@errors = $mailHTML->errstr;

If no errors where found, it'll return undef.

=head1 AUTHOR

Alain BARBET alian@alianwebserver.com

=cut
