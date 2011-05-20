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
    PDF::WebKit::Configuration->configure(sub {
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

  describe "command" => sub {
    it "should construct the correct command" => sub {
      my $pdfkit = PDF::WebKit->new(\'html', page_size => 'Letter', toc_l1_font_size => 12);
      my @command = $pdfkit->command;
      like( $command[0], qr/\Q$wkhtmltopdf/ );
      is( $command[index_of('"--page-size"',@command) + 1], '"Letter"' );
      is( $command[index_of('"--toc-l1-font-size"',@command) + 1], '"12"' );
      is( $command[-3], '"--quiet"' );
      is( $command[-2], '"-"' );  # from stdin
      is( $command[-1], '"-"' );  # to stdout
    };

    it "will not include default options it is told to omit" => sub {
      PDF::WebKit::Configuration->configure(sub {
        $_->default_options->{disable_smart_shrinking} = 'yes';
      });
      my $pdfkit = PDF::WebKit->new(\'html');
      my @command = $pdfkit->command;
      ok( index_of('"--disable-smart-shrinking"',@command) );
      isnt( $command[index_of('"--disable-smart-shrinking"',@command) + 1], 'yes' );

      $pdfkit = PDF::WebKit->new(\'html', disable_smart_shrinking => undef);
      @command = $pdfkit->command;
      is( index_of('"--disable-smart-shrinking"',@command), undef );
    };

    it "should encapsulate string arguments in quotes" => sub {
      my $pdfkit = PDF::WebKit->new(\'html', header_center => "foo [page]");
      my @command = $pdfkit->command;
      is( $command[ index_of('"--header-center"',@command) + 1 ], '"foo [page]"' );
    };

    it "reads the source from stdin if it is html" => sub {
      my $pdfkit = PDF::WebKit->new(\'html');
      my @command = $pdfkit->command;
      is_deeply( [@command[-2,-1]], ['"-"', '"-"'] );
    };

    it "specifies the URL to the source if it is a URL" => sub {
      my $pdfkit = PDF::WebKit->new('http://google.com');
      my @command = $pdfkit->command;
      is_deeply( [@command[-2,-1]], ['"http://google.com"', '"-"'] );
    };

    it "should specify the path to the source if it is a file" => sub {
      my $file_path = File::Spec->catfile($SPEC_ROOT,'fixtures','example.html');
      my $pdfkit = PDF::WebKit->new($file_path);
      my @command = $pdfkit->command;
      is_deeply( [@command[-2,-1]], [qq{"$file_path"}, '"-"'] );
    };

    it "should specify the path for the output if a path is given" => sub {
      my $file_path = "/path/to/output.pdf";
      my $pdfkit = PDF::WebKit->new(\"html");
      my @command = $pdfkit->command($file_path);
      is($command[-1], qq{"$file_path"});
    };

#    it "should detect special pdf-webkit meta tags" => sub {
#      local $TODO = 1;
#      my $body = q{
#        <html>
#          <head>
#            <meta name="pdfkit-page_size" content="Legal"/>
#            <meta name="pdfkit-orientation" content="Landscape"/>
#          </head>
#        </html>
#      };
#      my $pdfkit = PDF::WebKit->new(\$body);
#      my @command = $pdfkit->command;
#      is( $command[ index_of('"--page-size"',@command) + 1 ], '"Legal"' );
#      is( $command[ index_of('"--orientation"',@command) + 1 ], '"Landscape"' );
#    };
  };

};

runtests unless caller;

__END__


describe PDFKit do

  context "#to_pdf" => sub {
    it "should generate a PDF of the HTML" => sub {
      pdfkit = PDF::WebKit->new('html', :page_size => 'Letter')
      pdf = pdfkit.to_pdf
      pdf[0...4].should == "%PDF" # PDF Signature at beginning of file
    };

    it "should generate a PDF with a numerical parameter" => sub {
      pdfkit = PDF::WebKit->new('html', :header_spacing => 1)
      pdf = pdfkit.to_pdf
      pdf[0...4].should == "%PDF" # PDF Signature at beginning of file
    };

    it "should generate a PDF with a symbol parameter" => sub {
      pdfkit = PDF::WebKit->new('html', :page_size => :Letter)
      pdf = pdfkit.to_pdf
      pdf[0...4].should == "%PDF" # PDF Signature at beginning of file
    };

    it "should have the stylesheet added to the head if it has one" => sub {
      pdfkit = PDF::WebKit->new("<html><head></head><body>Hai!</body></html>")
      css = File.join(SPEC_ROOT,'fixtures','example.css')
      pdfkit.stylesheets << css
      pdfkit.to_pdf
      pdfkit.source.to_s.should include("<style>#{File.read(css)}</style>")
    };

    it "should prepend style tags if the HTML doesn't have a head tag" => sub {
      pdfkit = PDF::WebKit->new("<html><body>Hai!</body></html>")
      css = File.join(SPEC_ROOT,'fixtures','example.css')
      pdfkit.stylesheets << css
      pdfkit.to_pdf
      pdfkit.source.to_s.should include("<style>#{File.read(css)}</style><html>")
    };

    it "should throw an error if the source is not html and stylesheets have been added" => sub {
      pdfkit = PDF::WebKit->new('http://google.com')
      css = File.join(SPEC_ROOT,'fixtures','example.css')
      pdfkit.stylesheets << css
      lambda { pdfkit.to_pdf }.should raise_error(PDFKit::ImproperSourceError)
    };
  };

  context "#to_file" => sub {
    before => sub {
      @file_path = File.join(SPEC_ROOT,'fixtures','test.pdf')
      File.delete(@file_path) if File.exist?(@file_path)
    };

    after => sub {
      File.delete(@file_path)
    };

    it "should create a file with the PDF as content" => sub {
      pdfkit = PDF::WebKit->new('html', :page_size => 'Letter')
      file = pdfkit.to_file(@file_path)
      file.should be_instance_of(File)
      File.read(file.path)[0...4].should == "%PDF" # PDF Signature at beginning of file
    };
  };

  context "security" => sub {
    before => sub {
      @test_path = File.join(SPEC_ROOT,'fixtures','security-oops')
      File.delete(@test_path) if File.exist?(@test_path)
    };

    after => sub {
      File.delete(@test_path) if File.exist?(@test_path)
    };

    it "should not allow shell injection in options" => sub {
      pdfkit = PDF::WebKit->new('html', :header_center => "a title\"; touch #{@test_path} #")
      pdfkit.to_pdf
      File.exist?(@test_path).should be_false
    };
  };

};
