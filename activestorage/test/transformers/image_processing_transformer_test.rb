# frozen_string_literal: true

require "test_helper"

class ActiveStorage::Transformers::ImageProcessingTransformerTest < ActiveSupport::TestCase
  UnsupportedImageProcessingMethod = ActiveStorage::Transformers::ImageProcessingTransformer::UnsupportedImageProcessingMethod
  UnsupportedImageProcessingArgument = ActiveStorage::Transformers::ImageProcessingTransformer::UnsupportedImageProcessingArgument

  TRANSFORMERS = {
    vips: ActiveStorage::Transformers::Vips,
    mini_magick: ActiveStorage::Transformers::ImageMagick
  }

  TRANSFORMERS.each do |name, transformer|
    test "#{name} rejects Ruby reflection methods (CVE-2025-24293)" do
      %w[instance_eval instance_exec class_eval eval system exec send public_send __send__ method tap].each do |method|
        assert_raises(UnsupportedImageProcessingMethod, "expected #{method} to be rejected") do
          validate transformer, method => "`id > /tmp/pwned`"
        end
      end
    end

    test "#{name} rejects ImageProcessing pipeline methods that would bypass validation" do
      assert_raises(UnsupportedImageProcessingMethod) do
        validate transformer, apply: { instance_eval: "`id > /tmp/pwned`" }
      end

      assert_raises(UnsupportedImageProcessingMethod) do
        validate transformer, custom: "anything"
      end
    end

    test "#{name} rejects combine_options" do
      assert_raises(ArgumentError) do
        validate transformer, combine_options: { resize: "100x100" }
      end
    end

    test "#{name} rejects dangerous argument strings" do
      assert_raises(UnsupportedImageProcessingArgument) do
        validate transformer, resize: "-write /tmp/file.erb"
      end

      assert_raises(UnsupportedImageProcessingArgument) do
        validate transformer, resize: "-PaTh /tmp/file.erb"
      end
    end

    test "#{name} rejects dangerous arguments nested in arrays" do
      assert_raises(UnsupportedImageProcessingArgument) do
        validate transformer, resize: [ 123, "-write", "/tmp/file.erb" ]
      end

      assert_raises(UnsupportedImageProcessingArgument) do
        validate transformer, resize: [ 123, [ "-write", "/tmp/file.erb" ] ]
      end
    end

    test "#{name} rejects dangerous arguments nested in hashes" do
      assert_raises(UnsupportedImageProcessingArgument) do
        validate transformer, resize: { "-write": "/tmp/file.erb" }
      end

      assert_raises(UnsupportedImageProcessingArgument) do
        validate transformer, resize: { something: "-write /tmp/file.erb" }
      end

      assert_raises(UnsupportedImageProcessingArgument) do
        validate transformer, resize: { something: { "-write": "/tmp/file.erb" } }
      end

      assert_raises(UnsupportedImageProcessingArgument) do
        validate transformer, resize: { something: [ "-write", "/tmp/file.erb" ] }
      end
    end

    test "#{name} allows common transformations" do
      assert_nothing_raised do
        validate transformer, resize_to_limit: [ 100, 100 ], colourspace: "b-w", rotate: 90, convert: "png"
      end
    end
  end

  test "vips allows libvips operations absent from the ImageMagick allowlist" do
    assert_nothing_raised do
      validate ActiveStorage::Transformers::Vips,
        thumbnail_image: 100,
        saver: { optimize_gif_frames: true, optimize_gif_transparency: true }
    end
  end

  test "vips rejects libvips operations that read from or write to the filesystem" do
    %w[thumbnail jpegload pngsave dzsave magickload profile_load remosaic].each do |method|
      assert_raises(UnsupportedImageProcessingMethod, "expected #{method} to be rejected") do
        validate ActiveStorage::Transformers::Vips, method => "/tmp/file.erb"
      end
    end
  end

  test "mini_magick rejects libvips operation names" do
    assert_raises(UnsupportedImageProcessingMethod) do
      validate ActiveStorage::Transformers::ImageMagick, thumbnail_image: 100
    end
  end

  test "vips rejects ImageMagick option names" do
    assert_raises(UnsupportedImageProcessingMethod) do
      validate ActiveStorage::Transformers::Vips, annotate: "text"
    end
  end

  private
    def validate(transformer, transformations)
      transformer.new(transformations).send(:operations)
    end
end
