# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{activeresource}
  s.version = "3.0.pre"

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1") if s.respond_to? :required_rubygems_version=
  s.authors = ["David Heinemeier Hansson"]
  s.autorequire = %q{active_resource}
  s.date = %q{2009-09-01}
  s.description = %q{Wraps web resources in model classes that can be manipulated through XML over REST.}
  s.email = %q{david@loudthinking.com}
  s.extra_rdoc_files = ["README"]
  s.files = ["Rakefile", "README", "CHANGELOG", "lib/active_resource", "lib/active_resource/base.rb", "lib/active_resource/connection.rb", "lib/active_resource/custom_methods.rb", "lib/active_resource/exceptions.rb", "lib/active_resource/formats", "lib/active_resource/formats/json_format.rb", "lib/active_resource/formats/xml_format.rb", "lib/active_resource/formats.rb", "lib/active_resource/http_mock.rb", "lib/active_resource/observing.rb", "lib/active_resource/validations.rb", "lib/active_resource/version.rb", "lib/active_resource.rb", "lib/activeresource.rb", "test/abstract_unit.rb", "test/cases", "test/cases/authorization_test.rb", "test/cases/base", "test/cases/base/custom_methods_test.rb", "test/cases/base/equality_test.rb", "test/cases/base/load_test.rb", "test/cases/base_errors_test.rb", "test/cases/base_test.rb", "test/cases/finder_test.rb", "test/cases/format_test.rb", "test/cases/observing_test.rb", "test/cases/validations_test.rb", "test/connection_test.rb", "test/debug.log", "test/fixtures", "test/fixtures/beast.rb", "test/fixtures/customer.rb", "test/fixtures/person.rb", "test/fixtures/project.rb", "test/fixtures/proxy.rb", "test/fixtures/street_address.rb", "test/setter_trap.rb", "examples/simple.rb"]
  s.homepage = %q{http://www.rubyonrails.org}
  s.rdoc_options = ["--main", "README"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{activeresource}
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{Think Active Record for web resources.}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<activesupport>, ["= 3.0.pre"])
      s.add_runtime_dependency(%q<activemodel>, ["= 3.0.pre"])
    else
      s.add_dependency(%q<activesupport>, ["= 3.0.pre"])
      s.add_dependency(%q<activemodel>, ["= 3.0.pre"])
    end
  else
    s.add_dependency(%q<activesupport>, ["= 3.0.pre"])
    s.add_dependency(%q<activemodel>, ["= 3.0.pre"])
  end
end
