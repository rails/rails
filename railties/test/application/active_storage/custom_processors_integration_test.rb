# frozen_string_literal: true

require "isolation/abstract_unit"

module ApplicationTests
  class ActiveStorageCustomProcessorsTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    self.file_fixture_path = "#{RAILS_FRAMEWORK_ROOT}/activestorage/test/fixtures/files"

    def setup
      build_app

      rails "active_storage:install"

      rails "generate", "model", "user", "name:string", "avatar:attachment"
      rails "db:migrate"

      app_file "config/initializers/custom_media_processing.rb", <<~RUBY
        require "tempfile"

        class CustomAnalyzer < ActiveStorage::Analyzer
          def self.accept?(blob)
            blob.image?
          end

          def metadata
            { analyzed_by: "CustomAnalyzer" }
          end
        end

        class CustomTransformer < ActiveStorage::Transformers::Transformer
          private
            def process(file, format:)
              Tempfile.new([ "custom", ".\#{format}" ], binmode: true).tap do |output|
                output.write("\#{transformations.inspect} as \#{format}")
                output.rewind
              end
            end
        end

        Rails.application.config.active_storage.analyzers = [ CustomAnalyzer ]
        Rails.application.config.active_storage.variant_processor = CustomTransformer
      RUBY
    end

    def teardown
      teardown_app
    end

    def test_custom_analyzer_extracts_metadata
      app("development")

      user = User.create!(name: "Test User", avatar: file_fixture("racecar.jpg"))

      assert_equal "CustomAnalyzer", user.avatar.blob.reload.metadata["analyzed_by"]
    end

    def test_custom_transformer_produces_the_variant
      app("development")

      user = User.create!(name: "Test User", avatar: file_fixture("racecar.jpg"))
      variant = user.avatar.variant(resize_to_limit: [ 100, 100 ]).processed

      assert_equal "#{{ resize_to_limit: [ 100, 100 ] }.inspect} as jpg", variant.image.download
    end
  end
end
