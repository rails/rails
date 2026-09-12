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

    def test_boots_when_ruby_vips_cannot_load_its_libraries
      File.open("#{app_path}/Gemfile", "a") { |f| f.puts 'gem "image_processing", "~> 2.0"' }
      add_ruby_vips_stub 'require "vips"'
      File.write app_path("ruby-vips", "lib", "vips.rb"), <<~'RUBY'
        raise LoadError, "Could not open library 'glib-2.0.0': dlopen(glib-2.0.0, 0x0005): tried: 'glib-2.0.0' (no such file)."
      RUBY

      output = run_command("puts :booted")

      assert_predicate $?, :success?
      assert_includes(output, "booted")
      assert_includes(output, "Using vips to process variants requires the libvips library.")
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
