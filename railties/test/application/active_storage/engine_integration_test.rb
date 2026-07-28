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

    def test_signed_ids_are_url_safe_with_message_pack_serializer
      File.open("#{app_path}/Gemfile", "a") do |f|
        f.puts 'gem "msgpack"'
      end

      add_to_config <<~RUBY
        config.secret_key_base = "secret"
        config.active_support.message_serializer = :message_pack
      RUBY

      # A blob's signed ID is used as a path segment in the Active Storage routes,
      # so a "+" or "/" in its Base64 encoding breaks routing. Pick a blob id whose
      # non-URL-safe encoding exposes the problem, then assert it is encoded safely.
      script = <<~RUBY.gsub("\n", " ")
        secret = Rails.application.key_generator.generate_key('ActiveStorage');
        unsafe = ActiveSupport::MessageVerifier.new(secret);
        blob_id = (1..1000).find { |id| s = unsafe.generate(id, purpose: :blob_id); s.include?('+') || s.include?('/') };
        signed = ActiveStorage.verifier.generate(blob_id, purpose: :blob_id);
        url_safe = !(signed.include?('+') || signed.include?('/'));
        round_trips = ActiveStorage.verifier.verified(signed, purpose: :blob_id) == blob_id;
        puts(url_safe && round_trips ? 'URL_SAFE_OK' : 'URL_SAFE_FAIL');
      RUBY

      output = run_command(script)

      assert_includes(output, "URL_SAFE_OK")
      assert_not_includes(output, "URL_SAFE_FAIL")
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
