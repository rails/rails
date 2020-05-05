# frozen_string_literal: true

version = File.read(File.expand_path("../RAILS_VERSION", __dir__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = "actioncable"
  s.version     = version
  s.summary     = "WebSocket framework for Rails."
  s.description = "Structure many real-time application concerns into channels over a single WebSocket connection."

  s.required_ruby_version = ">= 2.5.0"

  s.license = "MIT"

  s.author   = ["Pratik Naik", "David Heinemeier Hansson"]
  s.email    = ["pratiknaik@gmail.com", "david@loudthinking.com"]
  s.homepage = "https://rubyonrails.org"

  s.files        = Dir["CHANGELOG.md", "MIT-LICENSE", "README.md", "lib/**/*", "app/assets/javascripts/action_cable.js"]
  s.require_path = "lib"

  s.metadata = {
    "bug_tracker_uri"   => "https://github.com/rails/rails/issues",
    "changelog_uri"     => "https://github.com/rails/rails/blob/v#{version}/actioncable/CHANGELOG.md",
    "documentation_uri" => "https://api.rubyonrails.org/v#{version}/",
    "mailing_list_uri"  => "https://discuss.rubyonrails.org/c/rubyonrails-talk",
    "source_code_uri"   => "https://github.com/rails/rails/tree/v#{version}/actioncable",
  }

  # NOTE: Please read our dependency guidelines before updating versions:
  # https://edgeguides.rubyonrails.org/security.html#dependency-management-and-cves

  s.add_dependency "activesupport", version
  s.add_dependency "actionpack", version

  s.add_dependency "nio4r",            "~> 2.0"
  s.add_dependency "websocket-driver", ">= 0.6.1"
end
