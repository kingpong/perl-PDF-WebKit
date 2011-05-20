#!perl
use Test::Spec;
use utf8;

use File::Basename qw(dirname);
use File::Spec;

BEGIN { require File::Spec->catfile(dirname(__FILE__), "spec_helper.pl") }

describe "PDF::WebKit" => sub {

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

};

runtests unless caller;

__END__


describe PDFKit do

  context "command" => sub {
    it "should contstruct the correct command" => sub {
      pdfkit = PDF::WebKit->new('html', :page_size => 'Letter', :toc_l1_font_size => 12)
      pdfkit.command[0].should include('wkhtmltopdf')
      pdfkit.command[pdfkit.command.index('"--page-size"') + 1].should == '"Letter"'
      pdfkit.command[pdfkit.command.index('"--toc-l1-font-size"') + 1].should == '"12"'
    };

    it "will not include default options it is told to omit" => sub {
      PDFKit.configure do |config|
        config.default_options[:disable_smart_shrinking] = true
      };

      pdfkit = PDF::WebKit->new('html')
      pdfkit.command.should include('"--disable-smart-shrinking"')
      pdfkit = PDF::WebKit->new('html', :disable_smart_shrinking => false)
      pdfkit.command.should_not include('"--disable-smart-shrinking"')
    };

    it "should encapsulate string arguments in quotes" => sub {
      pdfkit = PDF::WebKit->new('html', :header_center => "foo [page]")
      pdfkit.command[pdfkit.command.index('"--header-center"') + 1].should == '"foo [page]"'
    };

    it "read the source from stdin if it is html" => sub {
      pdfkit = PDF::WebKit->new('html')
      pdfkit.command[-2..-1].should == ['"-"', '"-"']
    };

    it "specify the URL to the source if it is a url" => sub {
      pdfkit = PDF::WebKit->new('http://google.com')
      pdfkit.command[-2..-1].should == ['"http://google.com"', '"-"']
    };

    it "should specify the path to the source if it is a file" => sub {
      file_path = File.join(SPEC_ROOT,'fixtures','example.html')
      pdfkit = PDF::WebKit->new(File.new(file_path))
      pdfkit.command[-2..-1].should == [%Q{"#{file_path}"}, '"-"']
    };

    it "should specify the path for the ouput if a apth is given" => sub {
      file_path = "/path/to/output.pdf"
      pdfkit = PDF::WebKit->new("html")
      pdfkit.command(file_path).last.should == %Q{"#{file_path}"}
    };

    it "should detect special pdfkit meta tags" => sub {
      body = %{
        <html>
          <head>
            <meta name="pdfkit-page_size" content="Legal"/>
            <meta name="pdfkit-orientation" content="Landscape"/>
          </head>
        </html>
      }
      pdfkit = PDF::WebKit->new(body)
      pdfkit.command[pdfkit.command.index('"--page-size"') + 1].should == '"Legal"'
      pdfkit.command[pdfkit.command.index('"--orientation"') + 1].should == '"Landscape"'
    };
  };

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
