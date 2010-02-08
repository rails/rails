Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'actionmailer'
  s.version     = '3.0.0.beta1'
  s.summary     = 'Email composition, delivery, and recieval framework (part of Rails).'
  s.description = 'Email composition, delivery, and recieval framework (part of Rails).'
  s.required_ruby_version = '>= 1.8.7'

  s.author            = 'David Heinemeier Hansson'
  s.email             = 'david@loudthinking.com'
  s.homepage          = 'http://www.rubyonrails.org'
  s.rubyforge_project = 'actionmailer'

  s.files        = Dir['CHANGELOG', 'README', 'MIT-LICENSE', 'lib/**/*']
  s.require_path = 'lib'
  s.requirements << 'none'

  s.has_rdoc = true

  s.add_dependency('actionpack',  '= 3.0.0.beta1')
  s.add_dependency('mail',        '~> 2.1.2')
  s.add_dependency('text-format', '~> 1.0.0')
end
