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
  %options = ( %options, $self->_find_options_in_meta($args->{source}) ) unless $self->source->is_url;
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
  my ($self,$body) = @_;
  my %options;
  my $prefix = $self->configuration->meta_tag_prefix;
  for my $pair ($self->_pdf_webkit_meta_tags($body)) {
    (my $name = $pair->{name}) =~ s{^\Q$prefix}{}s;
    $options{$name} = $pair->{value};
  }
  return %options;
}

sub _pdf_webkit_meta_tags {
  my ($self,$body) = @_;
  my $prefix = $self->configuration->meta_tag_prefix;
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
