$:.unshift "railties/lib"
require "rails/version"

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'rails'
  s.version     = Rails::VERSION::STRING
  s.summary     = 'Full-stack web-application framework.'
  s.description = 'Full-stack web-application framework.'
  s.required_ruby_version = '>= 1.8.7'

  s.author            = 'David Heinemeier Hansson'
  s.email             = 'david@loudthinking.com'
  s.homepage          = 'http://www.rubyonrails.org'
  s.rubyforge_project = 'rails'
  
  s.files = []
  s.require_path = []

  s.add_dependency('activesupport',    "= #{Rails::VERSION::STRING}")
  s.add_dependency('actionpack',       "= #{Rails::VERSION::STRING}")
  s.add_dependency('activerecord',     "= #{Rails::VERSION::STRING}")
  s.add_dependency('activeresource',   "= #{Rails::VERSION::STRING}")
  s.add_dependency('actionmailer',     "= #{Rails::VERSION::STRING}")
  s.add_dependency('railties',         "= #{Rails::VERSION::STRING}")
  s.add_dependency('bundler',          '>= 0.9.8')
end
