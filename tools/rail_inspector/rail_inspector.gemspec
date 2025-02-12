# frozen_string_literal: true

require_relative "lib/rail_inspector/version"

Gem::Specification.new do |spec|
  spec.name = "rail_inspector"
  spec.version = RailInspector::VERSION
  spec.authors = ["Hartley McGuire"]
  spec.email = ["skipkayhil@gmail.com"]

  spec.summary = "A collection of linters for rails/rails"
  spec.homepage = "https://github.com/skipkayhil/rail_inspector"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) || f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "prism", "~> 1.2"
  spec.add_dependency "thor", "~> 1.0"
end
