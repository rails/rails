# frozen_string_literal: true

version = File.read(File.expand_path("../RAILS_VERSION", __dir__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = "conductor"
  s.version     = version
  s.summary     = "Develop Rails using a web UI."
  s.description = "Escape the CLI to control and manage Rails with a web UI."

  s.required_ruby_version = ">= 2.5.0"

  s.license  = "MIT"

  s.authors  = ["David Heinemeier Hansson"]
  s.email    = ["david@loudthinking.com"]
  s.homepage = "https://rubyonrails.org"

  s.files        = Dir["CHANGELOG.md", "MIT-LICENSE", "README.md", "lib/**/*", "app/**/*", "config/**/*"]
  s.require_path = "lib"

  s.metadata = {
    "source_code_uri" => "https://github.com/rails/rails/tree/v#{version}/conductor",
    "changelog_uri"   => "https://github.com/rails/rails/blob/v#{version}/conductor/CHANGELOG.md"
  }

  # NOTE: Please read our dependency guidelines before updating versions:
  # https://edgeguides.rubyonrails.org/security.html#dependency-management-and-cves

  s.add_dependency "activesupport", version
  s.add_dependency "actionpack",    version
end
