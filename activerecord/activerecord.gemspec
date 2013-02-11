Gem::Specification.new do |s|
  s.name = 'activerecord'
  s.version = '2.3.17'
  s.summary = 'Implements the ActiveRecord pattern for ORM.'
  s.description = 'Implements the ActiveRecord pattern (Fowler, PoEAA) for ORM. It ties database tables and classes together for business objects, like Customer or Subscription, that can find, save, and destroy themselves without resorting to manual SQL.'

  s.author = 'David Heinemeier Hansson'
  s.email = 'david@loudthinking.com'
  s.homepage = 'http://www.rubyonrails.org'

  s.require_path = 'lib'
  s.files = ['README']
  s.rdoc_options = ['--main', 'README']
  s.extra_rdoc_files = ['README']

  s.add_dependency 'activesupport', '= 2.3.17'
end
