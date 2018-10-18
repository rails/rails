# frozen_string_literal: true

version = File.read(File.expand_path("../RAILS_VERSION", __dir__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = "activestorage"
  s.version     = version
  s.summary     = "Local and cloud file storage framework."
  s.description = "Attach cloud and local files in Rails applications."

  s.required_ruby_version = ">= 2.4.1"

  s.license = "MIT"

  s.author   = "David Heinemeier Hansson"
  s.email    = "david@loudthinking.com"
  s.homepage = "http://rubyonrails.org"

  s.files        = Dir["CHANGELOG.md", "MIT-LICENSE", "README.md", "lib/**/*", "app/**/*", "config/**/*", "db/**/*"]
  s.require_path = "lib"

  s.metadata = {
    "source_code_uri" => "https://github.com/rails/rails/tree/v#{version}/activestorage",
    "changelog_uri"   => "https://github.com/rails/rails/blob/v#{version}/activestorage/CHANGELOG.md"
  }

  s.add_dependency "actionpack", version
  s.add_dependency "activerecord", version

  s.add_dependency "marcel", "~> 0.3.1"
end
