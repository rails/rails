Gem::Specification.new do |s|
  s.name     = "activestorage"
  s.version  = "0.1"
  s.authors  = "David Heinemeier Hansson"
  s.email    = "david@basecamp.com"
  s.summary  = "Attach cloud and local files in Rails applications"
  s.homepage = "https://github.com/rails/activestorage"
  s.license  = "MIT"

  s.required_ruby_version = ">= 2.3.0"

  s.add_dependency "activesupport", ">= 5.1"
  s.add_dependency "activerecord", ">= 5.1"
  s.add_dependency "actionpack", ">= 5.1"
  s.add_dependency "activejob", ">= 5.1"

  s.add_development_dependency "bundler", "~> 1.15"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- test/*`.split("\n")
end
