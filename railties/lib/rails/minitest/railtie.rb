if defined?(Rake.application) && Rake.application.top_level_tasks.grep(/^(default$|test(:|$))/).any?
  ENV['RAILS_ENV'] ||= 'test'
end

module Rails
  class MinitestRailtie < Rails::Railtie
    config.app_generators do |c|
      c.test_framework :minitest, fixture: true,
                                  fixture_replacement: nil

      c.integration_tool :minitest
    end

    rake_tasks do
      load "rails/minitest/testing.rake"
    end
  end
end
