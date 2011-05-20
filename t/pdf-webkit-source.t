#!perl
use Test::Spec;
use utf8;
use strict;

use File::Basename qw(dirname);
use File::Spec;

BEGIN { require File::Spec->catfile(dirname(__FILE__), "spec_helper.pl") }

my $source;

describe "PDF::WebKit::Source" => sub {
  
  describe "->is_url" => sub {
    it "should return true if passed a URL-like string" => sub {
      $source = PDF::WebKit::Source->new('http://google.com');
      ok($source->is_url);
    };
    it "should return false if passed a filename (non-URL)" => sub {
      $source = PDF::WebKit::Source->new('/dev/null');
      ok(!$source->is_url);
    };
    it "should return false if passed a scalar reference (HTML document)" => sub {
      $source = PDF::WebKit::Source->new(\'<blink>Oh Hai!</blink>');
      ok(!$source->is_url);
    };
    it "should return false if passed HTML with embedded urls at the beginning of a line" => sub {
      $source = PDF::WebKit::Source->new(\"<blink>Oh Hai!</blink>\nhttp://www.google.com");
      ok(!$source->is_url);
    };
  };

  describe "->is_file" => sub {
    it "should return true if passed a filename (non-URL-like string)" => sub {
      $source = PDF::WebKit::Source->new('/dev/null');
      ok($source->is_file);
    };
    it "should return false if passed a URL-like string" => sub {
      $source = PDF::WebKit::Source->new('http://google.com');
      ok(!$source->is_file);
    };
    it "should return false if passed a scalar reference (HTML document)" => sub {
      $source = PDF::WebKit::Source->new(\'<blink>Oh Hai!</blink>');
      ok(!$source->is_file);
    };
  };

  describe "->is_html" => sub {
    it "should return true if passed a scalar reference (HTML document)" => sub {
      $source = PDF::WebKit::Source->new(\'<blink>Oh Hai!</blink>');
      ok($source->is_html);
    };
    it "should return false if passed a file" => sub {
      $source = PDF::WebKit::Source->new('/dev/null');
      ok(!$source->is_html);
    };
    it "should return false if passed a URL-like string" => sub {
      $source = PDF::WebKit::Source->new('http://google.com');
      ok(!$source->is_html);
    };
  };

  describe "->content" => sub {
    it "should return the HTML if passed HTML" => sub {
      $source = PDF::WebKit::Source->new(\'<blink>Oh Hai!</blink>');
      is($source->content, '<blink>Oh Hai!</blink>');
    };
    it "should return the filename if passed a filename" => sub {
      $source = PDF::WebKit::Source->new(__FILE__);
      is($source->content, __FILE__);
    };
    it "should return the URL if passed a URL-like string" => sub {
      $source = PDF::WebKit::Source->new('http://google.com');
      is($source->content, 'http://google.com');
    };
  };

};

runtests unless caller;
