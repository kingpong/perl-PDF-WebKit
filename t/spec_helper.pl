require File::Basename;
require File::Spec;

our $SPEC_ROOT = File::Basename::dirname(__FILE__);
unshift @INC, $SPEC_ROOT;
unshift @INC, File::Spec->catfile($SPEC_ROOT,"..","lib");

require PDF::WebKit;
