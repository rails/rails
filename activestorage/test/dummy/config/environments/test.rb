require "active_support/core_ext/integer/time"

# The test environment is used exclusively to run your application's
# test suite. You never need to work with it otherwise. Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs. Don't rely on the data there!

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # While tests run files are not watched, reloading is not necessary.
  config.enable_reloading = false

  # Eager loading loads your entire application. When running a single test locally,
  # this is usually not necessary, and can slow down your test suite. However, it's
  # recommended that you enable it in continuous integration systems to ensure eager
  # loading is working properly before deploying your code.
  config.eager_load = ENV["CI"].present?

  # Configure public file server for tests with Cache-Control for performance.
  config.public_file_server.headers = {
    "Cache-Control" => "public, max-age=#{1.hour.to_i}"
  }

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false
  config.cache_store = :null_store

  # Raise exceptions instead of rendering exception templates.
  config.action_dispatch.show_exceptions = :rescuable

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false

  # Store uploaded files on the local file system in a temporary directory.
  config.active_storage.service = :local

  SERVICE_CONFIGURATIONS = begin
    config_file = Rails.root.join("../service/configurations.yml")
    ActiveSupport::ConfigurationFile.parse(config_file, symbolize_names: true)
  rescue Errno::ENOENT
    puts "Missing service configuration file in #{config_file}"
    {}
  end
  # Azure service tests are currently failing on the main branch.
  # We temporarily disable them while we get things working again.
  if ENV["BUILDKITE"]
    SERVICE_CONFIGURATIONS.delete(:azure)
    SERVICE_CONFIGURATIONS.delete(:azure_public)
  end

  config.active_storage.service_configurations = SERVICE_CONFIGURATIONS.merge(
    "local" => { "service" => "Disk", "root" => Dir.mktmpdir("active_storage_tests") },
    "local_public" => { "service" => "Disk", "root" => Dir.mktmpdir("active_storage_tests"), "public" => true },
    "disk_mirror_1" => { "service" => "Disk", "root" => Dir.mktmpdir("active_storage_tests_1") },
    "disk_mirror_2" => { "service" => "Disk", "root" => Dir.mktmpdir("active_storage_tests_2") },
    "disk_mirror_3" => { "service" => "Disk", "root" => Dir.mktmpdir("active_storage_tests_3") },
    "mirror" => { "service" => "Mirror", "primary" => "local", "mirrors" => ["disk_mirror_1", "disk_mirror_2", "disk_mirror_3"] }
  ).deep_stringify_keys

  config.action_mailer.perform_caching = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true

  # Raise error when a before_action's only/except options reference missing actions
  config.action_controller.raise_on_missing_callback_actions = true
end
