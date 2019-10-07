# -*- encoding: utf-8 -*-
# stub: actionmailer 6.1.0.alpha ruby lib

Gem::Specification.new do |s|
  s.name = "actionmailer".freeze
  s.version = "6.1.0.alpha"

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "changelog_uri" => "https://github.com/rails/rails/blob/v6.1.0.alpha/actionmailer/CHANGELOG.md", "source_code_uri" => "https://github.com/rails/rails/tree/v6.1.0.alpha/actionmailer" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["David Heinemeier Hansson".freeze]
  s.date = "2019-10-05"
  s.description = "Email on Rails. Compose, deliver, and test emails using the familiar controller/view pattern. First-class support for multipart email and attachments.".freeze
  s.email = "david@loudthinking.com".freeze
  s.files = ["CHANGELOG.md".freeze, "MIT-LICENSE".freeze, "README.rdoc".freeze, "lib/action_mailer".freeze, "lib/action_mailer.rb".freeze, "lib/action_mailer/base.rb".freeze, "lib/action_mailer/collector.rb".freeze, "lib/action_mailer/delivery_job.rb".freeze, "lib/action_mailer/delivery_methods.rb".freeze, "lib/action_mailer/gem_version.rb".freeze, "lib/action_mailer/inline_preview_interceptor.rb".freeze, "lib/action_mailer/log_subscriber.rb".freeze, "lib/action_mailer/mail_delivery_job.rb".freeze, "lib/action_mailer/mail_helper.rb".freeze, "lib/action_mailer/message_delivery.rb".freeze, "lib/action_mailer/parameterized.rb".freeze, "lib/action_mailer/preview.rb".freeze, "lib/action_mailer/railtie.rb".freeze, "lib/action_mailer/rescuable.rb".freeze, "lib/action_mailer/test_case.rb".freeze, "lib/action_mailer/test_helper.rb".freeze, "lib/action_mailer/version.rb".freeze, "lib/rails".freeze, "lib/rails/generators".freeze, "lib/rails/generators/mailer".freeze, "lib/rails/generators/mailer/USAGE".freeze, "lib/rails/generators/mailer/mailer_generator.rb".freeze, "lib/rails/generators/mailer/templates".freeze, "lib/rails/generators/mailer/templates/application_mailer.rb.tt".freeze, "lib/rails/generators/mailer/templates/mailer.rb.tt".freeze]
  s.homepage = "https://rubyonrails.org".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.5.0".freeze)
  s.requirements = ["none".freeze]
  s.rubygems_version = "3.0.3".freeze
  s.summary = "Email composition and delivery framework (part of Rails).".freeze

  s.installed_by_version = "3.0.3" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<activesupport>.freeze, ["= 6.1.0.alpha"])
      s.add_runtime_dependency(%q<actionpack>.freeze, ["= 6.1.0.alpha"])
      s.add_runtime_dependency(%q<actionview>.freeze, ["= 6.1.0.alpha"])
      s.add_runtime_dependency(%q<activejob>.freeze, ["= 6.1.0.alpha"])
      s.add_runtime_dependency(%q<mail>.freeze, ["~> 2.5", ">= 2.5.4"])
      s.add_runtime_dependency(%q<rails-dom-testing>.freeze, ["~> 2.0"])
    else
      s.add_dependency(%q<activesupport>.freeze, ["= 6.1.0.alpha"])
      s.add_dependency(%q<actionpack>.freeze, ["= 6.1.0.alpha"])
      s.add_dependency(%q<actionview>.freeze, ["= 6.1.0.alpha"])
      s.add_dependency(%q<activejob>.freeze, ["= 6.1.0.alpha"])
      s.add_dependency(%q<mail>.freeze, ["~> 2.5", ">= 2.5.4"])
      s.add_dependency(%q<rails-dom-testing>.freeze, ["~> 2.0"])
    end
  else
    s.add_dependency(%q<activesupport>.freeze, ["= 6.1.0.alpha"])
    s.add_dependency(%q<actionpack>.freeze, ["= 6.1.0.alpha"])
    s.add_dependency(%q<actionview>.freeze, ["= 6.1.0.alpha"])
    s.add_dependency(%q<activejob>.freeze, ["= 6.1.0.alpha"])
    s.add_dependency(%q<mail>.freeze, ["~> 2.5", ">= 2.5.4"])
    s.add_dependency(%q<rails-dom-testing>.freeze, ["~> 2.0"])
  end
end
