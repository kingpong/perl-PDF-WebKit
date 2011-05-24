#!perl
use Test::Spec;
use utf8;

use File::Basename qw(dirname);
use File::Spec;

BEGIN { require File::Spec->catfile(dirname(__FILE__), "spec_helper.pl") }

# has to exist
my $wkhtmltopdf = File::Spec->catfile($SPEC_ROOT,'fixtures','mock_wkhtmltopdf');

describe "PDF::WebKit" => sub {

  before all => sub {
    PDF::WebKit->configure(sub {
      $_->wkhtmltopdf($wkhtmltopdf);
    });
  };

  describe "initialization" => sub {

    it "should accept HTML as the source when the source is a scalar reference" => sub {
      my $pdfkit = PDF::WebKit->new(\'<h1>Oh Hai</h1>');
      ok($pdfkit->source->is_html &&
         $pdfkit->source->content eq '<h1>Oh Hai</h1>');
    };

    it "should accept a URL as the source" => sub {
      my $pdfkit = PDF::WebKit->new('http://google.com');
      ok($pdfkit->source->is_url &&
         $pdfkit->source->content eq 'http://google.com');
    };

    it "should accept a File as the source" => sub {
      my $file_path = File::Spec->catfile($SPEC_ROOT,'fixtures','example.html');
      my $pdfkit = PDF::WebKit->new($file_path);
      ok($pdfkit->source->is_file &&
         $pdfkit->source->content eq $file_path);
    };

    it "should parse the options into a cmd line friendly format" => sub {
      my $pdfkit = PDF::WebKit->new('html', page_size => 'Letter');
      ok( exists $pdfkit->options->{"--page-size"} );
    };

    it "should provide default options" => sub {
      my $pdfkit = PDF::WebKit->new('<h1>Oh Hai</h1>');
      my $options = $pdfkit->options;
      ok( exists $options->{'--margin-top'} &&
          exists $options->{'--margin-right'} &&
          exists $options->{'--margin-bottom'} &&
          exists $options->{'--margin-left'});
    };

    it "should default to 'UTF-8' encoding" => sub {
      my $pdfkit = PDF::WebKit->new('Captación');
      is($pdfkit->options->{'--encoding'}, 'UTF-8');
    };

    it "should not have any stylesheet by default" => sub {
      my $pdfkit = PDF::WebKit->new('<h1>Oh Hai</h1>');
      is_deeply( $pdfkit->stylesheets, [] );
    };

  };

  describe "->command" => sub {
    it "should construct the correct command" => sub {
      my $pdfkit = PDF::WebKit->new(\'html', page_size => 'Letter', toc_l1_font_size => 12);
      my @command = $pdfkit->command;
      like( $command[0], qr/\Q$wkhtmltopdf/ );
      is( $command[index_of('--page-size',@command) + 1], 'Letter' );
      is( $command[index_of('--toc-l1-font-size',@command) + 1], '12' );
      is( $command[-3], '--quiet' );
      is( $command[-2], '-' );  # from stdin
      is( $command[-1], '-' );  # to stdout
    };

    it "will not include default options it is told to omit" => sub {
      PDF::WebKit->configure(sub {
        $_->default_options->{disable_smart_shrinking} = 'yes';
      });
      my $pdfkit = PDF::WebKit->new(\'html');
      my @command = $pdfkit->command;
      ok( index_of('--disable-smart-shrinking',@command) );
      isnt( $command[index_of('--disable-smart-shrinking',@command) + 1], 'yes' );

      $pdfkit = PDF::WebKit->new(\'html', disable_smart_shrinking => undef);
      @command = $pdfkit->command;
      is( index_of('--disable-smart-shrinking',@command), undef );
    };

    it "should encapsulate string arguments in quotes" => sub {
      my $pdfkit = PDF::WebKit->new(\'html', header_center => "foo [page]");
      my @command = $pdfkit->command;
      is( $command[ index_of('--header-center',@command) + 1 ], 'foo [page]' );
    };

    it "reads the source from stdin if it is html" => sub {
      my $pdfkit = PDF::WebKit->new(\'html');
      my @command = $pdfkit->command;
      is_deeply( [@command[-2,-1]], ['-', '-'] );
    };

    it "specifies the URL to the source if it is a URL" => sub {
      my $pdfkit = PDF::WebKit->new('http://google.com');
      my @command = $pdfkit->command;
      is_deeply( [@command[-2,-1]], ['http://google.com', '-'] );
    };

    it "should specify the path to the source if it is a file" => sub {
      my $file_path = File::Spec->catfile($SPEC_ROOT,'fixtures','example.html');
      my $pdfkit = PDF::WebKit->new($file_path);
      my @command = $pdfkit->command;
      is_deeply( [@command[-2,-1]], [$file_path, '-'] );
    };

    it "should specify the path for the output if a path is given" => sub {
      my $file_path = "/path/to/output.pdf";
      my $pdfkit = PDF::WebKit->new(\"html");
      my @command = $pdfkit->command($file_path);
      is($command[-1], $file_path);
    };

    SKIP: {
      skip "XML::LibXML is unavailable", 2
        unless eval { require XML::LibXML };

      it "should detect special pdf-webkit meta tags" => sub {
        my $body = q{
          <html>
            <head>
              <meta name="pdf-webkit-page_size" content="Legal"/>
              <meta name="pdf-webkit-orientation" content="Landscape"/>
            </head>
          </html>
        };
        my $pdfkit = PDF::WebKit->new(\$body);
        my @command = $pdfkit->command;
        is( $command[ index_of('--page-size',@command) + 1 ], 'Legal' );
        is( $command[ index_of('--orientation',@command) + 1 ], 'Landscape' );
      };
    }
  };

};

runtests unless caller;

