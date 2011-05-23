package PDF::WebKit;
use 5.008008;
use strict;
use warnings;
use Carp ();
use IO::File ();
use IPC::Open2 ();

use PDF::WebKit::Configuration;
use PDF::WebKit::Source;

# use decimal versioning to support extutils, with enough digits to
# (hopefully) match PDFKit's versioning.
our $VERSION = 0.500;

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
  %options = ( %{ $self->configuration->default_options }, %{ $args->{options} } );
  %options = ( %options, $self->_find_options_in_meta($self->source) ) unless $self->source->is_url;
  %options = $self->_normalize_options(%options);
  $self->_set_options(\%options);

  if (not -e $self->configuration->wkhtmltopdf) {
    my $msg = "No wkhtmltopdf executable found\n";
    $msg   .= ">> Please install wkhtmltopdf - https://github.com/jdpace/PDFKit/wiki/Installing-WKHTMLTOPDF";
    die $msg;
  }
}

sub configuration {
  PDF::WebKit::Configuration->configuration
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
    push @args, $self->source->content;
  }

  push @args, $path || '-'; # write to file or stdout

  return map { s/"/\\"/g; qq{"$_"} } grep { defined($_) } @args;
}

sub executable {
  my $self = shift;
  my $default = $self->configuration->wkhtmltopdf;
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
  my ($PDF_OUT,$PDF_IN);
  eval { IPC::Open2::open2($PDF_OUT, $PDF_IN, join(" ", @args)) };
  if ($@) {
    die "can't execute $args[0]: $!";
  }
  print {$PDF_IN} $self->source->content if $self->source->is_html;
  close($PDF_IN) || die $!;
  my $result = do { local $/; <$PDF_OUT> };
  if ($path) {
    $result = do { local (@ARGV,$/) = ($path); <> };
  }

  if (not (defined($result) && length($result))) {
    Carp::croak "command failed: $args[0]";
  }
  return $result;
}

sub to_file {
  my $self = shift;
  my $path = shift;
  $self->to_pdf($path);
  my $FH = IO::File->new($path,"<")
    || Carp::croak "can't open '$path': $!";
  $FH->binmode();
  return $FH;
}

sub _find_options_in_meta {
  my ($self,$source) = @_;
  # if we can't parse for whatever reason, keep calm and carry on.
  my @result = eval { $self->_pdf_webkit_meta_tags($source) };
  return $@ ? () : @result;
}

sub _pdf_webkit_meta_tags {
  my ($self,$source) = @_;
  return () unless eval { require XML::LibXML };

  my $prefix = $self->configuration->meta_tag_prefix;
  my $parser = XML::LibXML->new(
    recover => 2,
    suppress_errors => 1,
    suppress_warnings => 1,
    no_network => 1,
  );
  my $doc = $source->is_html ? $parser->parse_html_string($source->content)
          : $source->is_file ? $parser->parse_html_file($source->string)
          : return ();

  my %meta;
  for my $node ($doc->findnodes('html/head/meta')) {
    my $name = $node->getAttribute('name');
    next unless ($name && ($name =~ s{^\Q$prefix}{}s));
    $meta{$name} = $node->getAttribute('content');
  }

  return %meta;
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
  return unless $self->source->is_html;

  my $styles = join "", map { $self->style_tag_for($_) } @{$self->stylesheets};
  return unless length($styles) > 0;

  # can't modify in-place, because the source might be a reference to a
  # read-only constant string literal
  my $html = $self->source->content;
  if (not ($html =~ s{(?=</head>)}{$styles})) {
    $html = $styles . $html;
  }
  $self->source->string(\$html);
}

sub _normalize_options {
  my $self = shift;
  my %orig_options = @_;
  my %normalized_options;
  while (my ($key,$val) = each %orig_options) {
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

sub _normalize_value {
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

  use PDF::WebKit;

  # PDF::WebKit->new takes the HTML and any options for wkhtmltopdf
  # run `wkhtmltopdf --extended-help` for a full list of options
  my $kit = PDF::WebKit->new(\$html, page_size => 'Letter');
  push @{ $kit->stylesheets }, "/path/to/css/file";

  # Get an inline PDF
  my $pdf = $kit->to_pdf;

  # save the PDF to a file
  my $file = $kit->to_file('/path/to/save/pdf');

  # PDF::WebKit can optionally accept a URL or a File
  # Stylesheets cannot be added when source is provided as a URL or File.
  my $kit = PDF::WebKit->new('http://google.com');
  my $kit = PDF::WebKit->new('/path/to/html');

  # Add any kind of option through meta tags
  my $kit = PDF::WebKit->new(\'<html><head><meta name="pdfkit-page_size" content="Letter"...');

=head1 DESCRIPTION

PDF::WebKit uses L<wkhtmltopdf|> to convert HTML documents into PDFs. It
is a port of the wonderful L<PDFKit|https://github.com/jdpace/PDFKit>
Ruby library.

=cut
