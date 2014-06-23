package PDF::WebKit::Source;
use strict;
use warnings;

use Moo;
use namespace::clean;

has string => ( is => 'rw' );

around 'BUILDARGS' => sub {
  my $orig = shift;
  my $class = shift;
  if (@_ != 1) {
    die "Usage: ${class}->new(\$source)\n";
  }

  my $string = shift;
  return $class->$orig({ string => $string });
};

sub is_url {
  my $self = shift;
  return (!ref($self->string) && $self->string =~ /^https?:/i);
}

sub is_file {
  my $self = shift;
  return (!ref($self->string) && !$self->is_url);
}

sub is_html {
  my $self = shift;
  return ref($self->string) eq 'SCALAR';
}

sub content {
  my $self = shift;
  return ref($self->string) ? ${$self->string} : $self->string;
}

1;

