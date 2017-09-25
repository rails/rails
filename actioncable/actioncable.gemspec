# frozen_string_literal: true

version = File.read(File.expand_path("../RAILS_VERSION", __dir__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = "actioncable"
  s.version     = version
  s.summary     = "WebSocket framework for Rails."
  s.description = "Structure many real-time application concerns into channels over a single WebSocket connection."

  s.required_ruby_version = ">= 2.2.2"

  s.license = "MIT"

  s.author   = ["Pratik Naik", "David Heinemeier Hansson"]
  s.email    = ["pratiknaik@gmail.com", "david@loudthinking.com"]
  s.homepage = "http://rubyonrails.org"

  s.files        = Dir["CHANGELOG.md", "MIT-LICENSE", "README.md", "lib/**/*"]
  s.require_path = "lib"

  s.metadata = {
    "source_code_uri" => "https://github.com/rails/rails/tree/v#{version}/actioncable",
    "changelog_uri"   => "https://github.com/rails/rails/blob/v#{version}/actioncable/CHANGELOG.md"
  }

  s.add_dependency "actionpack", version

  s.add_dependency "nio4r",            "~> 2.0"
  s.add_dependency "websocket-driver", "~> 0.7.0"
end
