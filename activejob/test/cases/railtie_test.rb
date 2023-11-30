# frozen_string_literal: true

require "helper"
require "active_support/testing/isolation"

class RailtieTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  setup do
    require "rails"

    rails_logger = Logger.new(nil)

    @app ||= Class.new(::Rails::Application) do
      def self.name; "AJRailtieTestApp"; end

      config.eager_load = false
      config.logger = rails_logger
      config.active_support.cache_format_version = 7.1
    end
  end

  test "active_job.logger initializer does not overwrite the supplied logger" do
    custom_logger = Logger.new(nil)

    @app.config.before_initialize do |app|
      ActiveSupport.on_load(:active_job) do
        self.logger = custom_logger
      end
    end

    require "active_job/railtie"
    @app.initialize!

    assert_same ActiveJob::Base.logger, custom_logger
  end
end
