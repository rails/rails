# -*- encoding: utf-8 -*-
# stub: activejob 6.1.0.alpha ruby lib

Gem::Specification.new do |s|
  s.name = "activejob".freeze
  s.version = "6.1.0.alpha"

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "changelog_uri" => "https://github.com/rails/rails/blob/v6.1.0.alpha/activejob/CHANGELOG.md", "source_code_uri" => "https://github.com/rails/rails/tree/v6.1.0.alpha/activejob" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["David Heinemeier Hansson".freeze]
  s.date = "2019-10-05"
  s.description = "Declare job classes that can be run by a variety of queuing backends.".freeze
  s.email = "david@loudthinking.com".freeze
  s.files = ["CHANGELOG.md".freeze, "MIT-LICENSE".freeze, "README.md".freeze, "lib/active_job".freeze, "lib/active_job.rb".freeze, "lib/active_job/arguments.rb".freeze, "lib/active_job/base.rb".freeze, "lib/active_job/callbacks.rb".freeze, "lib/active_job/configured_job.rb".freeze, "lib/active_job/core.rb".freeze, "lib/active_job/enqueuing.rb".freeze, "lib/active_job/exceptions.rb".freeze, "lib/active_job/execution.rb".freeze, "lib/active_job/gem_version.rb".freeze, "lib/active_job/instrumentation.rb".freeze, "lib/active_job/log_subscriber.rb".freeze, "lib/active_job/logging.rb".freeze, "lib/active_job/queue_adapter.rb".freeze, "lib/active_job/queue_adapters".freeze, "lib/active_job/queue_adapters.rb".freeze, "lib/active_job/queue_adapters/async_adapter.rb".freeze, "lib/active_job/queue_adapters/backburner_adapter.rb".freeze, "lib/active_job/queue_adapters/delayed_job_adapter.rb".freeze, "lib/active_job/queue_adapters/inline_adapter.rb".freeze, "lib/active_job/queue_adapters/que_adapter.rb".freeze, "lib/active_job/queue_adapters/queue_classic_adapter.rb".freeze, "lib/active_job/queue_adapters/resque_adapter.rb".freeze, "lib/active_job/queue_adapters/sidekiq_adapter.rb".freeze, "lib/active_job/queue_adapters/sneakers_adapter.rb".freeze, "lib/active_job/queue_adapters/sucker_punch_adapter.rb".freeze, "lib/active_job/queue_adapters/test_adapter.rb".freeze, "lib/active_job/queue_name.rb".freeze, "lib/active_job/queue_priority.rb".freeze, "lib/active_job/railtie.rb".freeze, "lib/active_job/serializers".freeze, "lib/active_job/serializers.rb".freeze, "lib/active_job/serializers/date_serializer.rb".freeze, "lib/active_job/serializers/date_time_serializer.rb".freeze, "lib/active_job/serializers/duration_serializer.rb".freeze, "lib/active_job/serializers/module_serializer.rb".freeze, "lib/active_job/serializers/object_serializer.rb".freeze, "lib/active_job/serializers/symbol_serializer.rb".freeze, "lib/active_job/serializers/time_serializer.rb".freeze, "lib/active_job/serializers/time_with_zone_serializer.rb".freeze, "lib/active_job/test_case.rb".freeze, "lib/active_job/test_helper.rb".freeze, "lib/active_job/timezones.rb".freeze, "lib/active_job/translation.rb".freeze, "lib/active_job/version.rb".freeze, "lib/rails".freeze, "lib/rails/generators".freeze, "lib/rails/generators/job".freeze, "lib/rails/generators/job/job_generator.rb".freeze, "lib/rails/generators/job/templates".freeze, "lib/rails/generators/job/templates/application_job.rb.tt".freeze, "lib/rails/generators/job/templates/job.rb.tt".freeze]
  s.homepage = "https://rubyonrails.org".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.5.0".freeze)
  s.rubygems_version = "3.0.3".freeze
  s.summary = "Job framework with pluggable queues.".freeze

  s.installed_by_version = "3.0.3" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<activesupport>.freeze, ["= 6.1.0.alpha"])
      s.add_runtime_dependency(%q<globalid>.freeze, [">= 0.3.6"])
    else
      s.add_dependency(%q<activesupport>.freeze, ["= 6.1.0.alpha"])
      s.add_dependency(%q<globalid>.freeze, [">= 0.3.6"])
    end
  else
    s.add_dependency(%q<activesupport>.freeze, ["= 6.1.0.alpha"])
    s.add_dependency(%q<globalid>.freeze, [">= 0.3.6"])
  end
end
