# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::CustomTransformerTest < ActiveSupport::TestCase
  class AudioTransformer < ActiveStorage::Transformers::Transformer
    class << self
      attr_accessor :calls

      def accept?(blob)
        blob.content_type.to_s.start_with?("audio/")
      end
    end

    private
      def process(file, format:)
        self.class.calls = (self.class.calls || []) << { transformations: transformations, format: format }
        file
      end
  end

  class RejectingTransformer < ActiveStorage::Transformers::Transformer
    def self.accept?(blob)
      false
    end

    private
      def process(file, format:)
        raise "should not be called"
      end
  end

  setup do
    @was_transformers = ActiveStorage.transformers
    @was_tracking, ActiveStorage.track_variants = ActiveStorage.track_variants, false
    AudioTransformer.calls = []
  end

  teardown do
    ActiveStorage.transformers = @was_transformers
    ActiveStorage.track_variants = @was_tracking
  end

  test "blob is not variable when no registered transformer accepts it" do
    blob = create_file_blob(filename: "audio.mp3", content_type: "audio/mpeg")

    assert_not blob.variable?
    assert_raises ActiveStorage::InvariableError, match: /content_type=audio\/mpeg/ do
      blob.variant(format: :mp3)
    end
  end

  test "blob is variable when a registered transformer accepts it" do
    ActiveStorage.transformers += [ AudioTransformer ]
    blob = create_file_blob(filename: "audio.mp3", content_type: "audio/mpeg")

    assert blob.variable?
    assert_kind_of ActiveStorage::Variant, blob.variant(format: :mp3)
  end

  test "blob is not variable when the registered transformer rejects it" do
    ActiveStorage.transformers += [ RejectingTransformer ]
    blob = create_file_blob(filename: "audio.mp3", content_type: "audio/mpeg")

    assert_not blob.variable?
  end

  test "processing a variant uses the transformer that accepts the blob" do
    ActiveStorage.transformers += [ RejectingTransformer, AudioTransformer ]
    blob = create_file_blob(filename: "audio.mp3", content_type: "audio/mpeg")

    variant = blob.variant(format: :mp3, sample_rate: 44100).processed

    assert_equal 1, AudioTransformer.calls.size
    assert_equal({ sample_rate: 44100 }, AudioTransformer.calls.first[:transformations])
    assert_equal :mp3, AudioTransformer.calls.first[:format]
    assert_equal blob.download, variant.download
  end

  test "variant of a custom media type carries that type's content type" do
    ActiveStorage.transformers += [ AudioTransformer ]
    blob = create_file_blob(filename: "audio.mp3", content_type: "audio/mpeg")

    assert_equal "audio/mpeg", blob.variant(format: :mp3).content_type
  end

  test "representable? and representation follow variable?" do
    blob = create_file_blob(filename: "audio.mp3", content_type: "audio/mpeg")
    assert_not blob.representable?
    assert_raises ActiveStorage::UnrepresentableError do
      blob.representation(format: :mp3)
    end

    ActiveStorage.transformers += [ AudioTransformer ]

    assert blob.representable?
    assert_kind_of ActiveStorage::Variant, blob.representation(format: :mp3)
  end

  test "a previewable blob is still represented by its preview" do
    ActiveStorage.transformers += [ AudioTransformer ]
    blob = create_file_blob(filename: "video.mp4", content_type: "video/mp4")

    assert_kind_of ActiveStorage::Preview, blob.representation(resize_to_limit: [ 100, 100 ])
  end

  test "images remain variable through the default transformers" do
    blob = create_file_blob(filename: "racecar.jpg")

    assert blob.variable?

    variant = blob.variant(resize_to_limit: [ 100, 100 ]).processed
    image = read_image(variant)
    assert_equal 100, image.width
    assert_equal 67, image.height
  end

  test "images remain governed by variable_content_types" do
    was = ActiveStorage.variable_content_types
    ActiveStorage.variable_content_types = was - [ "image/jpeg" ]

    assert_not create_file_blob(filename: "racecar.jpg").variable?
  ensure
    ActiveStorage.variable_content_types = was
  end

  test "registering a transformer does not make unrelated types variable" do
    ActiveStorage.transformers += [ AudioTransformer ]

    assert_not create_blob(filename: "hello.txt", content_type: "text/plain").variable?
  end
end
