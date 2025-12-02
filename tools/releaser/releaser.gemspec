# frozen_string_literal: true

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = "releaser"
  s.version     = "1.0.0"
  s.summary     = "Library to release Rails"
  s.description = "A set of tasks to release Rails"

  s.required_ruby_version = ">= 3.2.0"

  s.license = "MIT"

  s.author   = "Rafael Mendonça França"
  s.email    = "rafael@rubyonrails.org"
  s.homepage = "https://rubyonrails.org"

  s.files = Dir["lib/**/*", "test/**/*", "RAILS_VERSION"]

  s.metadata = {
    "bug_tracker_uri" => "https://github.com/rails/rails/issues",
  }

  s.add_dependency "rake", "~> 13.0"
  s.add_dependency "minitest"
end
