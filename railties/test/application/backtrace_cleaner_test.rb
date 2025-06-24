# frozen_string_literal: true

require "env_helpers"

module ApplicationTests
  class BacktraceCleanerTest < ActiveSupport::TestCase
    include EnvHelpers

    setup do
      @cleaner = Rails::BacktraceCleaner.new
    end

    test "#clean silences Rails code from backtrace" do
      backtrace = [
        "app/controllers/foo_controller.rb:4:in 'index'",
        "#{Gem.default_dir}/gems/railties-1.2.3/lib/rails/engine.rb:536:in `call"
      ]

      cleaned = @cleaner.clean(backtrace)

      assert_equal ["app/controllers/foo_controller.rb:4:in 'index'"], cleaned
    end

    test "#clean does not silence when BACKTRACE is set" do
      switch_env("BACKTRACE", "1") do
        backtrace = [
          "app/app/controllers/foo_controller.rb:4:in 'index'",
          "#{Gem.default_dir}/gems/railties-1.2.3/lib/rails/engine.rb:536:in `call"
        ]

        cleaned = @cleaner.clean(backtrace)

        assert_equal backtrace, cleaned
      end
    end

    test "#clean_frame silences Rails code" do
      frame = "#{Gem.default_dir}/gems/railties-1.2.3/lib/rails/engine.rb:536:in `call"

      cleaned = @cleaner.clean_frame(frame)

      assert_nil cleaned
    end

    test "#clean_frame does not silence when BACKTRACE is set" do
      switch_env("BACKTRACE", "1") do
        frame = "#{Gem.default_dir}/gems/railties-1.2.3/lib/rails/engine.rb:536:in `call"

        cleaned = @cleaner.clean_frame(frame)

        assert_equal frame, cleaned
      end
    end
  end
end
