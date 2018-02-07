Gem::Specification.new do |s|
  s.name     = "activetext"
  s.version  = "0.1"
  s.authors  = ["Javan Makhmali", "Sam Stephenson"]
  s.email    = ["javan@javan.us", "sstephenson@gmail.com"]
  s.summary  = "Edit and display rich text in Rails applications"
  s.homepage = "https://github.com/basecamp/activetext"
  s.license  = "MIT"

  s.required_ruby_version = ">= 2.2.2"

  s.add_dependency "rails", ">= 5.2.0"
  s.add_dependency "activerecord", ">= 5.2.0"
  s.add_dependency "activestorage", ">= 5.2.0"

  s.add_development_dependency "bundler", "~> 1.15"

  s.files      = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- test/*`.split("\n")
end
