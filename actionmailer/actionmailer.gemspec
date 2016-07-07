version = File.read(File.expand_path('../../RAILS_VERSION', __FILE__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'actionmailer'
  s.version     = version
  s.summary     = 'Email composition, delivery, and receiving framework (part of Rails).'
  s.description = 'Email on Rails. Compose, deliver, receive, and test emails using the familiar controller/view pattern. First-class support for multipart email and attachments.'

  s.required_ruby_version = '>= 2.2.2'

  s.license = 'MIT'

  s.author   = 'David Heinemeier Hansson'
  s.email    = 'david@loudthinking.com'
  s.homepage = 'http://rubyonrails.org'

  s.files        = Dir['CHANGELOG.md', 'README.rdoc', 'MIT-LICENSE', 'lib/**/*']
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency 'actionpack', version
  s.add_dependency 'actionview', version
  s.add_dependency 'activejob', version

  s.add_dependency 'mail', ['~> 2.5', '>= 2.5.4']
  s.add_dependency 'rails-dom-testing', '~> 2.0'
end
