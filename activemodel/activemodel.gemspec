# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{activemodel}
  s.version = "3.0.pre"

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1") if s.respond_to? :required_rubygems_version=
  s.authors = ["David Heinemeier Hansson"]
  s.date = %q{2009-09-01}
  s.description = %q{Extracts common modeling concerns from ActiveRecord to share between similar frameworks like ActiveResource.}
  s.email = %q{david@loudthinking.com}
  s.files = ["CHANGELOG", "MIT-LICENSE", "README", "Rakefile", "lib/active_model", "lib/active_model/attribute_methods.rb", "lib/active_model/conversion.rb", "lib/active_model/deprecated_error_methods.rb", "lib/active_model/dirty.rb", "lib/active_model/errors.rb", "lib/active_model/lint.rb", "lib/active_model/locale", "lib/active_model/locale/en.yml", "lib/active_model/naming.rb", "lib/active_model/observing.rb", "lib/active_model/serialization.rb", "lib/active_model/serializers", "lib/active_model/serializers/json.rb", "lib/active_model/serializers/xml.rb", "lib/active_model/state_machine", "lib/active_model/state_machine/event.rb", "lib/active_model/state_machine/machine.rb", "lib/active_model/state_machine/state.rb", "lib/active_model/state_machine/state_transition.rb", "lib/active_model/state_machine.rb", "lib/active_model/test_case.rb", "lib/active_model/validations", "lib/active_model/validations/acceptance.rb", "lib/active_model/validations/confirmation.rb", "lib/active_model/validations/exclusion.rb", "lib/active_model/validations/format.rb", "lib/active_model/validations/inclusion.rb", "lib/active_model/validations/length.rb", "lib/active_model/validations/numericality.rb", "lib/active_model/validations/presence.rb", "lib/active_model/validations/with.rb", "lib/active_model/validations.rb", "lib/active_model/validations_repair_helper.rb", "lib/active_model/version.rb", "lib/active_model.rb", "lib/activemodel.rb", "test/cases", "test/cases/helper.rb", "test/cases/lint_test.rb", "test/cases/naming_test.rb", "test/cases/observing_test.rb", "test/cases/serializeration", "test/cases/serializeration/json_serialization_test.rb", "test/cases/serializeration/xml_serialization_test.rb", "test/cases/state_machine", "test/cases/state_machine/event_test.rb", "test/cases/state_machine/machine_test.rb", "test/cases/state_machine/state_test.rb", "test/cases/state_machine/state_transition_test.rb", "test/cases/state_machine_test.rb", "test/cases/tests_database.rb", "test/cases/validations", "test/cases/validations/acceptance_validation_test.rb", "test/cases/validations/conditional_validation_test.rb", "test/cases/validations/confirmation_validation_test.rb", "test/cases/validations/exclusion_validation_test.rb", "test/cases/validations/format_validation_test.rb", "test/cases/validations/i18n_generate_message_validation_test.rb", "test/cases/validations/i18n_validation_test.rb", "test/cases/validations/inclusion_validation_test.rb", "test/cases/validations/length_validation_test.rb", "test/cases/validations/numericality_validation_test.rb", "test/cases/validations/presence_validation_test.rb", "test/cases/validations/with_validation_test.rb", "test/cases/validations_test.rb", "test/config.rb", "test/fixtures", "test/fixtures/topics.yml", "test/models", "test/models/contact.rb", "test/models/custom_reader.rb", "test/models/developer.rb", "test/models/person.rb", "test/models/reply.rb", "test/models/topic.rb", "test/schema.rb"]
  s.homepage = %q{http://www.rubyonrails.org}
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{activemodel}
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{A toolkit for building other modeling frameworks like ActiveRecord}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<activesupport>, ["= 3.0.pre"])
    else
      s.add_dependency(%q<activesupport>, ["= 3.0.pre"])
    end
  else
    s.add_dependency(%q<activesupport>, ["= 3.0.pre"])
  end
end
