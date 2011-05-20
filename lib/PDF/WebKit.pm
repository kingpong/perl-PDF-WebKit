package PDF::WebKit;
use 5.008008;
use strict;
use warnings;
use Carp ();
use IPC::Open2 ();

use PDF::WebKit::Source;

our $VERSION = 0.5.0;

our %Default_Options;
our $Wkhtmltopdf;
our $Meta_Tag_Prefix = 'pdf-webkit-';

use Moose;

has source      => ( is => 'rw' );
has stylesheets => ( is => 'rw' );
has options     => ( is => 'ro', writer => '_set_options' );

around 'BUILDARGS' => sub {
  my $orig = shift;
  my $class = shift;

  if (@_ % 2 == 0) {
    Carp::croak "Usage: ${class}->new(\$url_file_or_html,%options)";
  }

  my $url_file_or_html = shift;
  my $options          = { @_ };
  return $class->$orig({ source => $url_file_or_html, options => $options });
};

sub BUILD {
  my ($self,$args) = @_;

  $self->source( PDF::WebKit::Source->new($args->{source}) );

  $self->stylesheets( [] );

  my %options;
  %options = ( %Default_Options, %{ $args->{options} } );
  %options = ( %options, $self->_find_options_in_meta($args->{source}) ) unless $self->source->is_url;
  %options = $self->_normalize_options(%options);
  $self->_set_options(\%options);

  if (not -e $Wkhtmltopdf) {
    my $msg = "No wkhtmltopdf executable found at $Wkhtmltopdf\n";
    $msg   .= ">> Please install wkhtmltopdf - https://github.com/jdpace/PDFKit/wiki/Installing-WKHTMLTOPDF";
    die $msg;
  }
}

sub command {
  my $self = shift;
  my $path = shift;
  my @args = ( $self->executable );
  push @args, %{ $self->options };
  push @args, '--quiet';
  
  if ($self->source->is_html) {
    push @args, '-';  # Get HTML from stdin
  }
  else {
    push @args, $self->source->string;
  }

  push @args, $path || '-'; # write to file or stdout

  return map { s/"/\\"/g; qq{"$_"} } grep { defined($_) } @args;
}

sub executable {
  my $self = shift;
  my $default = $Wkhtmltopdf;
  return $default if $default !~ /^\//; # it's not a path, so nothing we can do
  if (-e $default) {
    return $default;
  }
  else {
    return (split(/\//, $default))[-1];
  }
}

sub to_pdf {
  my $self = shift;
  my $path = shift;

  $self->_append_stylesheets;
  my @args = $self->command($path);
  IPC::Open2::open2(my $PDF_OUT, my $PDF_IN, @args)
    || die "can't execute $args[0]: $!";
  print {$PDF_IN} $self->source->to_s if $self->source->is_html;
  close($PDF_IN) || die $!;
  my $result = do { local $/; <$PDF_OUT> };
  if ($path) {
    $result = do { local (@ARGV,$/) = ($path); <> };
  }

  if ($result !~ /\S/) {
    Carp::croak "command failed: $args[0]";
  }
  return $result;
}

sub to_file {
  my $self = shift;
  my $path = shift;
  $self->to_pdf($path);
  open(my $FH, "<", $path) || Carp::croak "can't open '$path': $!";
  return $FH;
}

sub _find_options_in_meta {
  my ($self,$body) = @_;
  my %options;
  for my $pair ($self->_pdf_webkit_meta_tags($body)) {
    (my $name = $pair->{name}) =~ s{^$Meta_Tag_Prefix}{}s;
    $options{$name} = $pair->{value};
  }
  return %options;
}

sub _pdf_webkit_meta_tags {
  my ($self,$body) = @_;
  # TODO: parse html document and return those that match $Meta_Tag_Prefix
  return ();  # { name => x, value => y } x 0..INF
}

sub style_tag_for {
  my ($self,$stylesheet) = @_;
  my $styles = do { local (@ARGV,$/) = ($stylesheet); <> };
  return "<style>$styles</style>";
}

sub _append_stylesheets {
  my $self = shift;
  if (@{ $self->stylesheets } && !$self->source->is_html) {
    Carp::croak "stylesheets may only be added to an HTML source";
  }

  my $styles = join "", map { $self->style_tag_for($_) } @{$self->stylesheets};
  return unless length($styles) > 0;

  my $body = $self->source->string;
  if (not $body =~ s{(?=</head>)}{$styles}) {
    $body = $styles . $body;
  }

  $self->source->string($body);
}

sub _normalize_options {
  my $self = shift;
  my %normalized_options;
  my $orig_options = $self->options;
  while (my ($key,$val) = %$orig_options) {
    next unless defined($val) && length($val);
    my $normalized_key = "--" . $self->_normalize_arg($key);
    $normalized_options{$normalized_key} = $self->_normalize_value($val);
  }
  return %normalized_options;
}

sub _normalize_arg {
  my ($self,$arg) = @_;
  $arg =~ lc($arg);
  $arg =~ s{[^a-z0-9]}{-}g;
  return $arg;
}

sub normalize_value {
  my ($self,$value) = @_;
  if (defined($value) && ($value eq 'yes' || $value eq 'YES')) {
    return undef;
  }
  else {
    return $value;
  }
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

=head1 NAME

PDF::WebKit - Use WebKit to Generate PDFs from HTML (via wkhtmltopdf)

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

__END__

class PDFKit

  protected

    def pdfkit_meta_tags(body)
      require 'rexml/document'
      xml_body = REXML::Document.new(body)
      found = []
      xml_body.elements.each("html/head/meta") do |tag|
        found << tag if tag.attributes['name'].to_s =~ /^#{PDFKit.configuration.meta_tag_prefix}/
      end
      found
    rescue # rexml random crash on invalid xml
      []
    end

end
