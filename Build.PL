use Module::Build;
my $build = Module::Build->new(
  module_name => 'PDF::WebKit',
  license  => 'perl',
  requires => {
    'Moose' => 0,
  },
  build_requires => {
    'Test::Spec' => '>= 0.28',
  },
);
$build->create_build_script;
