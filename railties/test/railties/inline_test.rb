# frozen_string_literal: true

require "isolation/abstract_unit"

class Rails::RunnerTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  setup :setup_app
  teardown :teardown_app

  def test_default_config
    app_file "inline.rb", <<-RUBY
      require "bundler/inline"

      gemfile(true) do
        source "https://rubygems.org"

        gem "rails", path: "#{File.join(__dir__, "../../..")}"
      end

      require "rails/inline"

      rails_app do |config|
        config.root = __dir__
      end

      config = Rails.application.config
      puts "root: " + config.root.to_s
      puts "eager_load: " + config.eager_load.inspect
      puts "host: " + config.hosts.last
      puts "secret_key_base: " + config.secret_key_base
    RUBY

    output = run_inline_script("inline.rb")
    assert_match(/root: #{app_path}/, output)
    assert_match(/eager_load: false/, output)
    assert_match(/host: example.org/, output)
    assert_match(/secret_key_base: secret_key_base/, output)
  end

  def test_running_tests
    app_file "inline.rb", <<-RUBY
      require "bundler/inline"

      gemfile(true) do
        source "https://rubygems.org"

        gem "rails", path: "#{File.join(__dir__, "../../..")}"
      end

      require "rails/inline"
      require "minitest/autorun"

      rails_app do |config|
        config.root = __dir__
      end

      class BugTest < ActiveSupport::TestCase
        def test_example
          assert true
        end
      end
    RUBY

    assert_match /1 runs, 1 assertions, 0 failures, 0 errors, 0 skips/, run_inline_script("inline.rb")
  end

  def test_running_commands
    app_file "inline.rb", <<-RUBY
      require "bundler/inline"

      gemfile(true) do
        source "https://rubygems.org"

        gem "rails", path: "#{File.join(__dir__, "../../..")}"
      end

      require "rails/inline"

      rails_app do |config|
        config.root = __dir__
      end

      rails :version
    RUBY

    assert_match %r(Rails #{Rails.version}), run_inline_script("inline.rb")
  end

  private
    def run_inline_script(name)
      `ruby #{app_path}/#{name}`
    end
end
