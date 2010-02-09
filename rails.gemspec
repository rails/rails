Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'rails'
  s.version     = '3.0.0.beta1'
  s.summary     = 'Full-stack web-application framework.'
  s.description = 'Full-stack web-application framework.'
  s.required_ruby_version = '>= 1.8.7'

  s.author            = 'David Heinemeier Hansson'
  s.email             = 'david@loudthinking.com'
  s.homepage          = 'http://www.rubyonrails.org'
  s.rubyforge_project = 'rails'
  
  s.files = []
  s.require_path = []

  s.add_dependency('activesupport',    '= 3.0.0.beta1')
  s.add_dependency('actionpack',       '= 3.0.0.beta1')
  s.add_dependency('activerecord',     '= 3.0.0.beta1')
  s.add_dependency('activeresource',   '= 3.0.0.beta1')
  s.add_dependency('actionmailer',     '= 3.0.0.beta1')
  s.add_dependency('railties',         '= 3.0.0.beta1')
  s.add_dependency('bundler',          '>= 0.9.3')
end
