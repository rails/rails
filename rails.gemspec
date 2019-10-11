# -*- encoding: utf-8 -*-
# stub: rails 6.1.0.alpha ruby lib

Gem::Specification.new do |s|
  s.name = "rails".freeze
  s.version = "6.1.0.alpha"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.8.11".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["David Heinemeier Hansson".freeze]
  s.date = "2019-10-05"
  s.description = "Ruby on Rails is a full-stack web framework optimized for programmer happiness and sustainable productivity. It encourages beautiful code by favoring convention over configuration.".freeze
  s.email = "david@loudthinking.com".freeze
  s.files = ["README.md".freeze]
  s.homepage = "https://rubyonrails.org".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.5.0".freeze)
  s.rubygems_version = "3.0.3".freeze
  s.summary = "Full-stack web application framework.".freeze

  s.installed_by_version = "3.0.3" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<activesupport>.freeze, ["= 6.1.0.alpha"])
      s.add_runtime_dependency(%q<actionpack>.freeze, ["= 6.1.0.alpha"])
      s.add_runtime_dependency(%q<actionview>.freeze, ["= 6.1.0.alpha"])
      s.add_runtime_dependency(%q<activemodel>.freeze, ["= 6.1.0.alpha"])
      s.add_runtime_dependency(%q<activerecord>.freeze, ["= 6.1.0.alpha"])
      s.add_runtime_dependency(%q<actionmailer>.freeze, ["= 6.1.0.alpha"])
      s.add_runtime_dependency(%q<activejob>.freeze, ["= 6.1.0.alpha"])
      s.add_runtime_dependency(%q<actioncable>.freeze, ["= 6.1.0.alpha"])
      s.add_runtime_dependency(%q<activestorage>.freeze, ["= 6.1.0.alpha"])
      s.add_runtime_dependency(%q<actionmailbox>.freeze, ["= 6.1.0.alpha"])
      s.add_runtime_dependency(%q<actiontext>.freeze, ["= 6.1.0.alpha"])
      s.add_runtime_dependency(%q<railties>.freeze, ["= 6.1.0.alpha"])
      s.add_runtime_dependency(%q<bundler>.freeze, [">= 1.3.0"])
      s.add_runtime_dependency(%q<sprockets-rails>.freeze, [">= 2.0.0"])
    else
      s.add_dependency(%q<activesupport>.freeze, ["= 6.1.0.alpha"])
      s.add_dependency(%q<actionpack>.freeze, ["= 6.1.0.alpha"])
      s.add_dependency(%q<actionview>.freeze, ["= 6.1.0.alpha"])
      s.add_dependency(%q<activemodel>.freeze, ["= 6.1.0.alpha"])
      s.add_dependency(%q<activerecord>.freeze, ["= 6.1.0.alpha"])
      s.add_dependency(%q<actionmailer>.freeze, ["= 6.1.0.alpha"])
      s.add_dependency(%q<activejob>.freeze, ["= 6.1.0.alpha"])
      s.add_dependency(%q<actioncable>.freeze, ["= 6.1.0.alpha"])
      s.add_dependency(%q<activestorage>.freeze, ["= 6.1.0.alpha"])
      s.add_dependency(%q<actionmailbox>.freeze, ["= 6.1.0.alpha"])
      s.add_dependency(%q<actiontext>.freeze, ["= 6.1.0.alpha"])
      s.add_dependency(%q<railties>.freeze, ["= 6.1.0.alpha"])
      s.add_dependency(%q<bundler>.freeze, [">= 1.3.0"])
      s.add_dependency(%q<sprockets-rails>.freeze, [">= 2.0.0"])
    end
  else
    s.add_dependency(%q<activesupport>.freeze, ["= 6.1.0.alpha"])
    s.add_dependency(%q<actionpack>.freeze, ["= 6.1.0.alpha"])
    s.add_dependency(%q<actionview>.freeze, ["= 6.1.0.alpha"])
    s.add_dependency(%q<activemodel>.freeze, ["= 6.1.0.alpha"])
    s.add_dependency(%q<activerecord>.freeze, ["= 6.1.0.alpha"])
    s.add_dependency(%q<actionmailer>.freeze, ["= 6.1.0.alpha"])
    s.add_dependency(%q<activejob>.freeze, ["= 6.1.0.alpha"])
    s.add_dependency(%q<actioncable>.freeze, ["= 6.1.0.alpha"])
    s.add_dependency(%q<activestorage>.freeze, ["= 6.1.0.alpha"])
    s.add_dependency(%q<actionmailbox>.freeze, ["= 6.1.0.alpha"])
    s.add_dependency(%q<actiontext>.freeze, ["= 6.1.0.alpha"])
    s.add_dependency(%q<railties>.freeze, ["= 6.1.0.alpha"])
    s.add_dependency(%q<bundler>.freeze, [">= 1.3.0"])
    s.add_dependency(%q<sprockets-rails>.freeze, [">= 2.0.0"])
  end
end
