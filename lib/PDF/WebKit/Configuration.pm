package PDF::WebKit::Configuration;
use strict;
use warnings;
use Moo;
use namespace::clean;

has meta_tag_prefix => ( is => 'rw' );
has default_options => ( is => 'rw' );
has wkhtmltopdf     => ( is => 'rw', builder => '_find_wkhtmltopdf', lazy => 1 );

around 'BUILDARGS' => sub {
  my $orig = shift;
  my $self = shift;
  return $self->$orig({
    meta_tag_prefix => 'pdf-webkit-',
    default_options => {
      disable_smart_shrinking => undef,
      page_size => 'Letter',
      margin_top => '0.75in',
      margin_right => '0.75in',
      margin_bottom => '0.75in',
      margin_left => '0.75in',
      encoding => "UTF-8",
    },
  });
};

sub _find_wkhtmltopdf {
  my $self = shift;
  my $which = $^O eq "MSWin32" ? "where" : "which";
  my $found = `$which wkhtmltopdf`;
  if ($? == 0) {
    chomp($found);
    return $found;
  }
  else {
    return undef;
  }
}

my $_config;
sub configuration {
  $_config ||= PDF::WebKit::Configuration->new;
}

sub configure {
  my $class = shift;
  my $code = shift;
  local $_ = $class->configuration;
  $code->($_);
}

1;
