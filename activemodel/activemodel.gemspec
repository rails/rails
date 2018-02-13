# frozen_string_literal: true

version = File.read(File.expand_path("../RAILS_VERSION", __dir__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = "activemodel"
  s.version     = version
  s.summary     = "A toolkit for building modeling frameworks (part of Rails)."
  s.description = "A toolkit for building modeling frameworks like Active Record. Rich support for attributes, callbacks, validations, serialization, internationalization, and testing."

  s.required_ruby_version = ">= 2.2.2"

  s.license = "MIT"

  s.author   = "David Heinemeier Hansson"
  s.email    = "david@loudthinking.com"
  s.homepage = "http://rubyonrails.org"

  s.files        = Dir["CHANGELOG.md", "MIT-LICENSE", "README.rdoc", "lib/**/*"]
  s.require_path = "lib"

  s.metadata = {
    "source_code_uri" => "https://github.com/rails/rails/tree/v#{version}/activemodel",
    "changelog_uri"   => "https://github.com/rails/rails/blob/v#{version}/activemodel/CHANGELOG.md"
  }

  s.add_dependency "activesupport", version
end
