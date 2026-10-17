# frozen_string_literal: true

require "isolation/abstract_unit"

module ApplicationTests
  class ActiveStorageTransformersTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    self.file_fixture_path = "#{RAILS_FRAMEWORK_ROOT}/activestorage/test/fixtures/files"

    def setup
      build_app

      rails "active_storage:install"

      rails "generate", "model", "user", "name:string", "recording:attachment"
      rails "db:migrate"

      app_file "config/initializers/custom_transformers.rb", <<~RUBY
        require "tempfile"

        class AudioTransformer < ActiveStorage::Transformers::Transformer
          def self.accept?(blob)
            blob.content_type.to_s.start_with?("audio/")
          end

          private
            def process(file, format:)
              Tempfile.new([ "audio", ".\#{format}" ], binmode: true).tap do |output|
                output.write("\#{transformations.inspect} as \#{format}")
                output.rewind
              end
            end
        end

        Rails.application.config.active_storage.transformers = [ AudioTransformer ]
      RUBY
    end

    def teardown
      teardown_app
    end

    def test_registered_transformer_makes_a_non_image_blob_variable
      app("development")

      user = User.create!(name: "Test User", recording: file_fixture("audio.mp3"))

      assert user.recording.variable?
    end

    def test_registered_transformer_produces_the_variant
      app("development")

      user = User.create!(name: "Test User", recording: file_fixture("audio.mp3"))
      variant = user.recording.variant(sample_rate: 44100).processed

      assert_equal "#{{ sample_rate: 44100 }.inspect} as mp3", variant.image.download
      assert_equal "audio/mpeg", variant.image.content_type
    end

    def test_images_still_go_through_the_variant_processor
      app("development")

      user = User.create!(name: "Test User", recording: file_fixture("racecar.jpg"))
      variant = user.recording.variant(resize_to_limit: [ 100, 100 ]).processed

      assert_equal "image/jpeg", variant.image.content_type
    end
  end
end
