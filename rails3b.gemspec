Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'rails3b'
  s.version     = '3.0.1'
  s.summary     = 'Just the Rails 3 beta dependencies. Works around prerelease RubyGems bug.'
  s.description = 'My kingdom for working dependencies.'
  s.required_ruby_version = '>= 1.8.7'

  s.author            = 'Jeremy Kemper'
  s.email             = 'jeremy@bitsweat.net'

  s.files = []
  s.require_path = []

  s.add_dependency('mail',        '~> 2.1.2')
  s.add_dependency('text-format', '~> 1.0.0')
  s.add_dependency('rack',          '~> 1.1.0')
  s.add_dependency('rack-test',     '~> 0.5.0')
  s.add_dependency('rack-mount',    '= 0.4.7')
  s.add_dependency('erubis',        '~> 2.6.5')
  s.add_dependency('i18n',            '~> 0.3.0')
  s.add_dependency('tzinfo',          '~> 0.3.16')
  s.add_dependency('builder',         '~> 2.1.2')
  s.add_dependency('memcache-client', '~> 1.7.5')
  s.add_dependency('bundler',          '>= 0.9.2')
  s.add_dependency('rake',          '>= 0.8.3')
  s.add_dependency('thor',          '~> 0.13')
end
