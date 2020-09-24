# frozen_string_literal: true

version = File.read(File.expand_path("../RAILS_VERSION", __dir__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = "activesupport"
  s.version     = version
  s.summary     = "A toolkit of support libraries and Ruby core extensions extracted from the Rails framework."
  s.description = "A toolkit of support libraries and Ruby core extensions extracted from the Rails framework. Rich support for multibyte strings, internationalization, time zones, and testing."

  s.required_ruby_version = ">= 2.5.0"

  s.license = "MIT"

  s.author   = "David Heinemeier Hansson"
  s.email    = "david@loudthinking.com"
  s.homepage = "https://rubyonrails.org"

  s.files        = Dir["CHANGELOG.md", "MIT-LICENSE", "README.rdoc", "lib/**/*"]
  s.require_path = "lib"

  s.rdoc_options.concat ["--encoding",  "UTF-8"]

  s.metadata = {
    "bug_tracker_uri"   => "https://github.com/rails/rails/issues",
    "changelog_uri"     => "https://github.com/rails/rails/blob/v#{version}/activesupport/CHANGELOG.md",
    "documentation_uri" => "https://api.rubyonrails.org/v#{version}/",
    "mailing_list_uri"  => "https://discuss.rubyonrails.org/c/rubyonrails-talk",
    "source_code_uri"   => "https://github.com/rails/rails/tree/v#{version}/activesupport",
  }

  # NOTE: Please read our dependency guidelines before updating versions:
  # https://edgeguides.rubyonrails.org/security.html#dependency-management-and-cves

  s.add_dependency "i18n",            ">= 1.6", "< 2"
  s.add_dependency "tzinfo",          "~> 2.0"
  s.add_dependency "concurrent-ruby", "~> 1.0", ">= 1.0.2"
  s.add_dependency "zeitwerk",        "~> 2.4"
  s.add_dependency "minitest",        ">= 5.1"
  s.add_dependency "rexml"
end
