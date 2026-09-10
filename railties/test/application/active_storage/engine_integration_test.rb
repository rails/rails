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

      assert_includes(output, 'Generating image variants require the image_processing gem. Please add `gem "image_processing", "~> 2.0"` to your Gemfile')
    end

    def test_default_transformer_with_gem_no_warning
      File.open("#{app_path}/Gemfile", "a") do |f|
        f.puts <<~GEMFILE
          gem "image_processing", "~> 2.0"
          gem "ruby-vips", "~> 2.3"
        GEMFILE
      end

      output = run_command("puts ActiveStorage.variant_transformer")

      assert_not_includes(output, 'Generating image variants require the image_processing gem. Please add `gem "image_processing", "~> 2.0"` to your Gemfile')
      assert_includes(output, "ActiveStorage::Transformers::Vips")
    end

    def test_disabled_transformer_missing_gem_no_warning
      add_to_config "config.active_storage.variant_processor = :disabled"

      output = run_command("puts ActiveStorage.variant_transformer")

      assert_not_includes(output, 'Generating image variants require the image_processing gem. Please add `gem "image_processing", "~> 2.0"` to your Gemfile')
      assert_includes(output, "ActiveStorage::Transformers::NullTransformer")
    end

    def test_custom_transformer_without_image_gems_no_warning
      app_file "config/initializers/custom_transformer.rb", <<~RUBY
        class CustomTransformer < ActiveStorage::Transformers::Transformer
        end

        Rails.application.config.active_storage.variant_processor = CustomTransformer
      RUBY

      output = run_command("puts ActiveStorage.variant_transformer")

      assert_not_includes(output, 'Generating image variants require the image_processing gem. Please add `gem "image_processing", "~> 2.0"` to your Gemfile')
      assert_includes(output, "CustomTransformer")
    end

    def test_unknown_transformer_raises
      add_to_config "config.active_storage.variant_processor = :nope"

      output = run_command("puts ActiveStorage.variant_transformer")

      assert_not_predicate $?, :success?
      assert_includes(output, "ArgumentError")
      assert_includes(output, "Unknown variant processor :nope")
    end

    def test_mini_magick_transformer_boots_with_unsecurable_vips
      add_to_config "config.active_storage.variant_processor = :mini_magick"
      add_ruby_vips_stub "module Vips; end"

      output = run_command("puts :booted")

      assert_includes(output, "booted")
    end

    def test_vips_transformer_raises_at_boot_with_unsecurable_vips
      add_to_config "config.active_storage.variant_processor = :vips"
      add_ruby_vips_stub "module Vips; end"

      output = run_command("puts :booted")

      assert_not_includes(output, "booted")
      assert_includes(output, "remove the ruby-vips gem from your Gemfile. (RuntimeError)")
    end

    def test_block_untrusted_runs_before_initializers_without_vips_transformer
      add_to_config "config.active_storage.variant_processor = :mini_magick"
      add_ruby_vips_stub <<~'RUBY'
        module Vips
          def self.block_untrusted(state) = puts("block_untrusted(#{state})")
        end
      RUBY
      app_file "config/initializers/probe.rb", 'puts "initializer"'

      output = run_command("puts :booted")

      assert_equal %w[block_untrusted(true) initializer booted], output.lines.map(&:chomp).grep(/^(block_untrusted|initializer|booted)/)
    end

    private
      def add_ruby_vips_stub(source)
        FileUtils.mkdir_p app_path("ruby-vips", "lib")

        File.write app_path("ruby-vips", "ruby-vips.gemspec"), <<~RUBY
          Gem::Specification.new do |spec|
            spec.name = "ruby-vips"
            spec.version = "2.3.0"
            spec.summary = "ruby-vips stub"
            spec.authors = [ "Rails test" ]
            spec.files = [ "lib/ruby-vips.rb" ]
          end
        RUBY

        File.write app_path("ruby-vips", "lib", "ruby-vips.rb"), source

        File.open app_path("Gemfile"), "a" do |f|
          f.puts %(gem "ruby-vips", path: "#{app_path("ruby-vips")}")
        end
      end

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
