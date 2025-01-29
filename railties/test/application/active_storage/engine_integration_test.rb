# frozen_string_literal: true

require "isolation/abstract_unit"

require "env_helpers"

module ApplicationTests
  class ActiveStorageEngineTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    include EnvHelpers

    def setup
      build_app

      File.write app_path("Gemfile"), <<~GEMFILE
        source "https://rubygems.org"
        gem "rails", path: "#{RAILS_FRAMEWORK_ROOT}"

        gem "propshaft"
        gem "importmap-rails"
        gem "sqlite3"
      GEMFILE

      add_to_env_config :development, "config.active_storage.logger = ActiveSupport::Logger.new(STDOUT)"

      File.open("#{app_path}/config/boot.rb", "w") do |f|
        f.puts "ENV['BUNDLE_GEMFILE'] = '#{app_path}/Gemfile'"
        f.puts 'require "bundler/setup"'
      end
    end

    def teardown
      teardown_app
    end

    def test_default_transformer_missing_gem_warning
      output = run_command("puts ActiveStorage.variant_transformer")

      assert_includes(output, "Generating image variants require the image_processing gem. Please add `gem 'image_processing', '~> 1.2'` to your Gemfile.")
    end

    def test_default_transformer_with_gem_no_warning
      File.open("#{app_path}/Gemfile", "a") do |f|
        f.puts <<~GEMFILE
          gem "image_processing", "~> 1.2"
        GEMFILE
      end

      output = run_command("puts ActiveStorage.variant_transformer")

      assert_not_includes(output, "Generating image variants require the image_processing gem. Please add `gem 'image_processing', '~> 1.2'` to your Gemfile.")
      assert_includes(output, "ActiveStorage::Transformers::Vips")
    end

    def test_disabled_transformer_no_warning
      add_to_config "config.active_storage.variant_processor = :disabled"

      output = run_command("puts ActiveStorage.variant_transformer")

      assert_not_includes(output, "Generating image variants require the image_processing gem. Please add `gem 'image_processing', '~> 1.2'` to your Gemfile.")
      assert_includes(output, "ActiveStorage::Transformers::NullTransformer")
    end

    def test_invalid_transformer_is_deprecated
      add_to_env_config :development, "config.active_support.deprecation = :stderr"

      add_to_config "config.active_storage.variant_processor = :invalid"
      add_to_config "config.active_storage.analyzers = []"

      output = run_command("puts [ActiveStorage.variant_transformer, ActiveStorage.analyzers].inspect")

      msg = <<~MSG.squish
        DEPRECATION WARNING: ActiveStorage.variant_processor must be set to :vips, :mini_magick, or :disabled. Passing :invalid is deprecated and will raise an exception in Rails 8.1.
      MSG

      assert_includes(output, msg)
      assert_includes(output, "[:invalid, []]")
    end

    private
      def run_command(cmd)
        Dir.chdir(app_path) do
          Bundler.with_original_env do
            with_rails_env "development" do
              `bin/rails runner "#{cmd}" 2>&1`
            end
          end
        end
      end
  end
end
