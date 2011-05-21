#!perl
use Test::Spec;
use utf8;

use File::Basename qw(dirname);
use File::Spec;

BEGIN { require File::Spec->catfile(dirname(__FILE__), "spec_helper.pl") }

my $executable = PDF::WebKit::Configuration->configuration->wkhtmltopdf;
if (not ($executable && -x $executable)) {
  plan skip_all => "wkhtmltopdf not available (make sure it's in your path)";
}

describe "PDF::WebKit" => sub {

  describe "->to_pdf" => sub {
    it "should generate a PDF of the HTML" => sub {
      my $pdfkit = PDF::WebKit->new(\'html', page_size => 'Letter');
      my $pdf = $pdfkit->to_pdf;
      is(substr($pdf,0,4), '%PDF'); # PDF Signature at beginning of file
    };

    it "should generate a PDF with a numerical parameter" => sub {
      my $pdfkit = PDF::WebKit->new(\'html', header_spacing => 1);
      my $pdf = $pdfkit->to_pdf;
      is(substr($pdf,0,4), '%PDF'); # PDF Signature at beginning of file
    };

    it "should have the stylesheet added to the head if it has one" => sub {
      my $pdfkit = PDF::WebKit->new(\"<html><head></head><body>Hai!</body></html>");
      my $stylesheet = File::Spec->catfile($SPEC_ROOT,'fixtures','example.css');
      push @{ $pdfkit->stylesheets }, $stylesheet;
      $pdfkit->to_pdf;
      my $css = do { local (@ARGV,$/) = ($stylesheet); <> };
      like($pdfkit->source->content, qr{<style>\Q$css\E</style>});
    };

    it "should prepend style tags if the HTML doesn't have a head tag" => sub {
      my $pdfkit = PDF::WebKit->new(\"<html><body>Hai!</body></html>");
      my $stylesheet = File::Spec->catfile($SPEC_ROOT,'fixtures','example.css');
      push @{ $pdfkit->stylesheets }, $stylesheet;
      $pdfkit->to_pdf;
      my $css = do { local (@ARGV,$/) = ($stylesheet); <> };
      like($pdfkit->source->content, qr{<style>\Q$css\E</style><html>});
    };

    it "should throw an error if the source is not html and stylesheets have been added" => sub {
      my $pdfkit = PDF::WebKit->new('http://google.com');
      my $stylesheet = File::Spec->catfile($SPEC_ROOT,'fixtures','example.css');
      push @{ $pdfkit->stylesheets }, $stylesheet;
      eval { $pdfkit->to_pdf };
      like($@, qr/stylesheet.*html/i);
    };

  };

  describe "->to_file" => sub {
    before each => sub {
      $file_path = File::Spec->catfile($SPEC_ROOT,'fixtures','test.pdf');
      unlink($file_path) if -e $file_path;
    };
    after each => sub {
      unlink($file_path);
    };

    it "should create a file with the PDF as content" => sub {
      my $pdfkit = PDF::WebKit->new(\'html', page_size => 'Letter');
      my $file = $pdfkit->to_file($file_path);
      ok( $file->isa('IO::File') );
      $file->read(my $buf,4) || die $!;
      is($buf, '%PDF'); # PDF Signature at beginning of file
    };
  };

  describe "security" => sub {
    before each => sub {
      $test_path = File::Spec->catfile($SPEC_ROOT,'fixtures','security-oops');
      unlink($test_path) if -e $test_path;
    };
    after each => sub {
      unlink($test_path) if -e $test_path;
    };

    it "should not allow shell injection in options" => sub {
      my $pdfkit = PDF::WebKit->new(\'html', header_center => "a title\"; touch $test_path #");
      $pdfkit->to_pdf;
      ok(! -e $test_path);
    };
  };

};

runtests unless caller;

