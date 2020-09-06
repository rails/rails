# frozen_string_literal: true

version = File.read(File.expand_path('../RAILS_VERSION', __dir__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'railties'
  s.version     = version
  s.summary     = 'Tools for creating, working with, and running Rails applications.'
  s.description = 'Rails internals: application bootup, plugins, generators, and rake tasks.'

  s.required_ruby_version = '>= 2.5.0'

  s.license = 'MIT'

  s.author   = 'David Heinemeier Hansson'
  s.email    = 'david@loudthinking.com'
  s.homepage = 'https://rubyonrails.org'

  s.files        = Dir['CHANGELOG.md', 'README.rdoc', 'MIT-LICENSE', 'RDOC_MAIN.rdoc', 'exe/**/*', 'lib/**/{*,.[a-z]*}']
  s.require_path = 'lib'

  s.bindir      = 'exe'
  s.executables = ['rails']

  s.rdoc_options << '--exclude' << '.'

  s.metadata = {
    'bug_tracker_uri'   => 'https://github.com/rails/rails/issues',
    'changelog_uri'     => "https://github.com/rails/rails/blob/v#{version}/railties/CHANGELOG.md",
    'documentation_uri' => "https://api.rubyonrails.org/v#{version}/",
    'mailing_list_uri'  => 'https://discuss.rubyonrails.org/c/rubyonrails-talk',
    'source_code_uri'   => "https://github.com/rails/rails/tree/v#{version}/railties",
  }

  # NOTE: Please read our dependency guidelines before updating versions:
  # https://edgeguides.rubyonrails.org/security.html#dependency-management-and-cves

  s.add_dependency 'activesupport', version
  s.add_dependency 'actionpack',    version

  s.add_dependency 'rake', '>= 0.8.7'
  s.add_dependency 'thor', '~> 1.0'
  s.add_dependency 'method_source'

  s.add_development_dependency 'actionview', version
end
