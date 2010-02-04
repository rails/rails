Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'rails'
  s.version     = '3.0.0.beta'
  s.summary     = 'Full-stack web-application framework.'
  s.description = 'Full-stack web-application framework.'

  s.author            = 'David Heinemeier Hansson'
  s.email             = 'david@loudthinking.com'
  s.homepage          = 'http://www.rubyonrails.org'
  s.rubyforge_project = 'rails'

  s.rdoc_options << '--exclude' << '.'
  s.has_rdoc = false

  s.add_dependency('activesupport',    '= 3.0.0.beta')
  s.add_dependency('actionpack',       '= 3.0.0.beta')
  s.add_dependency('activerecord',     '= 3.0.0.beta')
  s.add_dependency('activeresource',   '= 3.0.0.beta')
  s.add_dependency('actionmailer',     '= 3.0.0.beta')
  s.add_dependency('railties',         '= 3.0.0.beta')
  s.add_dependency('bundler',          '>= 0.9.1.pre1')
end
