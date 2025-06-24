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

    test "watchable_args does NOT include files in autoload path" do
      add_to_config <<-RUBY
        config.file_watcher = ActiveSupport::EventedFileUpdateChecker
      RUBY
      app_file "app/README.md", ""

      require "#{rails_root}/config/environment"

      files, _ = Rails.application.watchable_args
      assert_not_includes files, "#{rails_root}/app/README.md"
    end

    test "watchable_args does include dirs in autoload path" do
      add_to_config <<-RUBY
        config.file_watcher = ActiveSupport::EventedFileUpdateChecker
        config.autoload_paths += %W(#{rails_root}/manually-specified-path)
      RUBY
      app_dir "app/automatically-specified-path"
      app_dir "manually-specified-path"

      require "#{rails_root}/config/environment"

      _, dirs = Rails.application.watchable_args

      assert_includes dirs, "#{rails_root}/app/automatically-specified-path"
      assert_includes dirs, "#{rails_root}/manually-specified-path"
    end
  end
end
