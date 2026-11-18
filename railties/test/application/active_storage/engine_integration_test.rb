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

    def test_mini_magick_transformer_raises_at_boot_with_unsecurable_mini_magick
      add_to_config "config.active_storage.variant_processor = :mini_magick"
      add_gem_stub "mini_magick", "5.0.1", "module MiniMagick; end"

      output = run_command("puts :booted")

      assert_not_includes(output, "booted")
      assert_includes(output, "requires mini_magick 5.1 or later")
    end

    def test_vips_transformer_boots_with_unsecurable_mini_magick
      add_to_config "config.active_storage.variant_processor = :vips"
      add_gem_stub "mini_magick", "5.0.1", "module MiniMagick; end"

      output = run_command("puts :booted")

      assert_includes(output, "booted")
    end

    def test_image_magick_policy_is_applied_after_an_initializer_replaces_mini_magick_cli_env
      File.open("#{app_path}/Gemfile", "a") { |f| f.puts 'gem "mini_magick", "~> 5.1"' }
      app_file "config/initializers/mini_magick.rb", 'MiniMagick.cli_env = { "OMP_NUM_THREADS" => "1" }'

      output = run_command("puts MiniMagick.cli_env.inspect; puts ActiveStorage::ImageMagick::POLICY_DIRECTORY")
      cli_env, policy_directory = output.lines.last(2).map(&:chomp)

      assert_equal({ "OMP_NUM_THREADS" => "1", "MAGICK_CONFIGURE_PATH" => policy_directory }.inspect, cli_env)
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

    def test_boots_when_ruby_vips_cannot_load_its_libraries
      File.open("#{app_path}/Gemfile", "a") { |f| f.puts 'gem "image_processing", "~> 2.0"' }
      add_ruby_vips_stub 'require "vips"'
      File.write app_path("ruby-vips", "lib", "vips.rb"), <<~'RUBY'
        raise LoadError, "Could not open library 'glib-2.0.0': dlopen(glib-2.0.0, 0x0005): tried: 'glib-2.0.0' (no such file)."
      RUBY

      output = run_command("puts :booted")

      assert_includes(output, "booted")
    end

    def test_does_not_require_ruby_vips_again_after_it_fails_to_load
      File.open("#{app_path}/Gemfile", "a") { |f| f.puts 'gem "image_processing", "~> 2.0"' }
      add_ruby_vips_stub 'require "vips"'
      File.write app_path("ruby-vips", "lib", "vips.rb"), <<~'RUBY'
        raise "ruby-vips was required again after it failed to load" if $vips_required
        $vips_required = true
        raise LoadError, "Could not open library 'glib-2.0.0': dlopen(glib-2.0.0, 0x0005): tried: 'glib-2.0.0' (no such file)."
      RUBY

      output = run_command("puts :booted")

      assert_includes(output, "Using vips to process variants requires the libvips library")
      assert_includes(output, "booted")
    end

    private
      def add_ruby_vips_stub(source)
        add_gem_stub "ruby-vips", "2.3.0", source
      end

      def add_gem_stub(name, version, source)
        FileUtils.mkdir_p app_path(name, "lib")

        File.write app_path(name, "#{name}.gemspec"), <<~RUBY
          Gem::Specification.new do |spec|
            spec.name = "#{name}"
            spec.version = "#{version}"
            spec.summary = "#{name} stub"
            spec.authors = [ "Rails test" ]
            spec.files = [ "lib/#{name}.rb" ]
          end
        RUBY

        File.write app_path(name, "lib", "#{name}.rb"), source

        File.open app_path("Gemfile"), "a" do |f|
          f.puts %(gem "#{name}", path: "#{app_path(name)}")
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
