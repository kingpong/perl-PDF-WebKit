require File::Basename;
require File::Spec;

our $SPEC_ROOT = File::Basename::dirname(__FILE__);
unshift @INC, $SPEC_ROOT;
unshift @INC, File::Spec->catfile($SPEC_ROOT,"..","lib");

require PDF::WebKit;

sub index_of ($\@;$) {
  my ($what,$array,$position) = @_;
  $position ||= 0;
  for (my $i = $position; $i < @$array; $i++) {
    return $i if $array->[$i] eq $what;
  }
  return undef;
}

