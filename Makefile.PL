#!perl

use inc::Module::Install;

# Define metadata
name 'PDF-WebKit';
all_from 'lib/PDF/WebKit.pm';
license 'perl';

# Specific dependencies
requires 'Moose';
test_requires 'Test::Spec';

# Create Makefile
WriteAll();
