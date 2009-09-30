Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.name = 'actionmailer'
  s.summary = "Service layer for easy email delivery and testing."
  s.description = %q{Makes it trivial to test and deliver emails sent from a single service layer.}
  s.version = '3.0.pre'

  s.author = "David Heinemeier Hansson"
  s.email = "david@loudthinking.com"
  s.rubyforge_project = "actionmailer"
  s.homepage = "http://www.rubyonrails.org"

  s.add_dependency('actionpack', '= 3.0.pre')

  s.files = Dir['CHANGELOG', 'README', 'MIT-LICENSE', 'lib/**/*']
  s.has_rdoc = true
  s.requirements << 'none'
  s.require_path = 'lib'
  s.autorequire = 'action_mailer'
end
