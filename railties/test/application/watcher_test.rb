# frozen_string_literal: true

require "isolation/abstract_unit"

module ApplicationTests
  class WatcherTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    setup :build_app
    teardown :teardown_app

    def app
      @app ||= Rails.application
    end

    test "watchable_args classifies files included in autoload path" do
      add_to_config <<-RUBY
        config.file_watcher = ActiveSupport::EventedFileUpdateChecker
      RUBY
      app_file "app/README.md", ""

      require "#{rails_root}/config/environment"

      files, _ = Rails.application.watchable_args
      assert_includes files, "#{rails_root}/app/README.md"
    end
  end
end
