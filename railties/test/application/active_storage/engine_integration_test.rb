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

    private
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
