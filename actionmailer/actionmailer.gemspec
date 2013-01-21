Gem::Specification.new do |s|
  s.name = 'actionmailer'
  s.version = '2.3.15'
  s.summary = 'Service layer for easy email delivery and testing.'
  s.description = 'Makes it trivial to test and deliver emails sent from a single service layer.'

  s.author = 'David Heinemeier Hansson'
  s.email = 'david@loudthinking.com'
  s.homepage = 'http://www.rubyonrails.org'

  s.require_path = 'lib'

  s.add_dependency 'actionpack', '= 2.3.15'
end
