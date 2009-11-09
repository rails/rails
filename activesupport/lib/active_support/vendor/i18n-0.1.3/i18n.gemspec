Gem::Specification.new do |s|
  s.name = "i18n"
  s.version = "0.1.3"
  s.date = "2009-01-09"
  s.summary = "Internationalization support for Ruby"
  s.email = "rails-i18n@googlegroups.com"
  s.homepage = "http://rails-i18n.org"
  s.description = "Add Internationalization support to your Ruby application."
  s.has_rdoc = false
  s.authors = ['Sven Fuchs', 'Joshua Harvey', 'Matt Aimonetti', 'Stephan Soller', 'Saimon Moore']
  s.files = [
    'i18n.gemspec',
    'lib/i18n/backend/simple.rb',
    'lib/i18n/exceptions.rb',
    'lib/i18n.rb',
    'MIT-LICENSE',
    'README.textile'
  ]
  s.test_files = [
    'test/all.rb',
    'test/i18n_exceptions_test.rb',
    'test/i18n_test.rb',
    'test/locale/en.rb',
    'test/locale/en.yml',
    'test/simple_backend_test.rb'
  ]
end
