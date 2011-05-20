use Module::Build;
my $build = Module::Build->new(
  module_name => 'PDF::WebKit',
  license  => 'perl',
  requires => {
    'perl' => '>= 5.8.8',
    'Moose' => 0,
    'Readonly' => '1.03',
  },
  recommends => {
    'Readonly::XS' => 0,
  },
  build_requires => {
    'Test::Spec' => '>= 0.28',
  },
);
$build->create_build_script;
