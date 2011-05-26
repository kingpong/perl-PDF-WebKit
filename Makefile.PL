#!perl

use inc::Module::Install;

# Define metadata
name 'PDF-WebKit';
all_from 'lib/PDF/WebKit.pm';
license 'perl';

# Specific dependencies
requires 'IPC::Run';
requires 'Moose';
recommends 'XML::LibXML' => '1.62';
test_requires 'Test::Spec';

# Create Makefile
WriteAll();
