# frozen_string_literal: true

require "test_helper"

class ActiveStorage::Transformers::ImageProcessingTransformerTest < ActiveSupport::TestCase
  UnsupportedImageProcessingMethod = ActiveStorage::Transformers::ImageProcessingTransformer::UnsupportedImageProcessingMethod
  UnsupportedImageProcessingArgument = ActiveStorage::Transformers::ImageProcessingTransformer::UnsupportedImageProcessingArgument

  %i[ vips mini_magick ].each do |processor|
    test "#{processor} rejects Ruby reflection methods" do
      %w[ instance_eval instance_exec class_eval eval system exec send public_send __send__ method tap ].each do |method|
        assert_raises UnsupportedImageProcessingMethod, "expected #{method} to be rejected" do
          validate processor, method => "`id > /tmp/pwned`"
        end
      end
    end

    test "#{processor} rejects ImageProcessing pipeline methods that would bypass validation" do
      %w[ apply operation branch source call custom instrumenter ].each do |method|
        assert_raises UnsupportedImageProcessingMethod, "expected #{method} to be rejected" do
          validate processor, method => { instance_eval: "`id > /tmp/pwned`" }
        end
      end
    end

    test "#{processor} rejects combine_options" do
      assert_raises ArgumentError do
        validate processor, combine_options: { resize: "100x100" }
      end
    end

    test "#{processor} rejects dangerous argument strings" do
      assert_raises UnsupportedImageProcessingArgument do
        validate processor, resize: "-write /tmp/file.erb"
      end

      assert_raises UnsupportedImageProcessingArgument do
        validate processor, resize: "-PaTh /tmp/file.erb"
      end
    end

    test "#{processor} rejects dangerous arguments nested in arrays" do
      assert_raises UnsupportedImageProcessingArgument do
        validate processor, resize: [ 123, "-write", "/tmp/file.erb" ]
      end

      assert_raises UnsupportedImageProcessingArgument do
        validate processor, resize: [ 123, [ "-write", "/tmp/file.erb" ] ]
      end
    end

    test "#{processor} rejects dangerous arguments nested in hashes" do
      assert_raises UnsupportedImageProcessingArgument do
        validate processor, resize: { "-write": "/tmp/file.erb" }
      end

      assert_raises UnsupportedImageProcessingArgument do
        validate processor, resize: { something: "-write /tmp/file.erb" }
      end

      assert_raises UnsupportedImageProcessingArgument do
        validate processor, resize: { something: { "-write": "/tmp/file.erb" } }
      end

      assert_raises UnsupportedImageProcessingArgument do
        validate processor, resize: { something: [ "-write", "/tmp/file.erb" ] }
      end
    end

    test "#{processor} allows common transformations" do
      assert_nothing_raised do
        validate processor, resize_to_limit: [ 100, 100 ], colourspace: "b-w", rotate: 90, convert: "png"
      end
    end
  end

  test "vips allows libvips operations absent from the ImageMagick allowlist" do
    assert_nothing_raised do
      validate :vips, thumbnail_image: 100, saver: { optimize_gif_frames: true, optimize_gif_transparency: true }
    end
  end

  test "vips rejects libvips operations that read from or write to the filesystem" do
    %w[ write_to_file write_to_target thumbnail jpegload pngsave dzsave magickload profile_load remosaic icc_import icc_export icc_transform text loader ].each do |method|
      assert_raises UnsupportedImageProcessingMethod, "expected #{method} to be rejected" do
        validate :vips, method => "/tmp/file.erb"
      end
    end
  end

  test "vips rejects libvips operations that build an image instead of transforming one" do
    %w[ black eye grey identity perlin sines worley xyz zone mask_gaussian gaussnoise ].each do |method|
      assert_raises UnsupportedImageProcessingMethod, "expected #{method} to be rejected" do
        validate :vips, method => 100
      end
    end
  end

  test "vips rejects libvips metadata mutators" do
    %w[ set set_type set_value remove ].each do |method|
      assert_raises UnsupportedImageProcessingMethod, "expected #{method} to be rejected" do
        validate :vips, method => "orientation"
      end
    end
  end

  test "mini_magick rejects libvips operation names" do
    assert_raises UnsupportedImageProcessingMethod do
      validate :mini_magick, thumbnail_image: 100
    end
  end

  test "vips rejects ImageMagick option names" do
    assert_raises UnsupportedImageProcessingMethod do
      validate :vips, annotate: "text"
    end
  end

  test "each transformer uses its backend-specific allowlist" do
    assert_equal ActiveStorage.supported_vips_image_processing_methods,
      transformer_for(:vips).new({}).send(:supported_methods)
    assert_equal ActiveStorage.supported_image_processing_methods,
      transformer_for(:mini_magick).new({}).send(:supported_methods)
  end

  test "transformation names with dashes are normalized before validation" do
    assert_equal [[ "resize-to-limit", [ 100, 100 ] ]],
      validate(:vips, "resize-to-limit" => [ 100, 100 ])
  end

  test "unknown transformation methods are rejected with the normalized name" do
    error = assert_raises UnsupportedImageProcessingMethod do
      validate :vips, "not-a-vips-operation" => true
    end

    assert_match "not_a_vips_operation", error.message
  end

  test "transformations without arguments are validated but omitted from operations" do
    assert_empty validate(:vips, resize_to_limit: nil, rotate: false)

    assert_raises UnsupportedImageProcessingMethod do
      validate :vips, "not-a-vips-operation" => nil
    end
  end

  test "base transformer implementations fail closed without an allowlist" do
    transformer = Class.new(ActiveStorage::Transformers::ImageProcessingTransformer)

    assert_raises NotImplementedError do
      transformer.new(resize_to_limit: [ 100, 100 ]).send(:operations)
    end
  end

  test "custom Vips methods can be added to the configured allowlist" do
    methods = ActiveStorage.supported_vips_image_processing_methods
    ActiveStorage.supported_vips_image_processing_methods = methods + [ "custom_vips_operation" ]

    assert_nothing_raised do
      validate :vips, custom_vips_operation: "safe"
    end
  ensure
    ActiveStorage.supported_vips_image_processing_methods = methods
  end

  test "custom unsupported arguments are applied recursively" do
    arguments = ActiveStorage.unsupported_image_processing_arguments
    ActiveStorage.unsupported_image_processing_arguments = arguments + [ "-custom" ]

    assert_raises UnsupportedImageProcessingArgument do
      validate :vips, resize: { options: [ "safe", { value: "-custom" } ] }
    end
  ensure
    ActiveStorage.unsupported_image_processing_arguments = arguments
  end

  test "dangerous symbols are rejected as arguments" do
    assert_raises UnsupportedImageProcessingArgument do
      validate :vips, resize: :"-write"
    end
  end

  private
    def validate(processor, transformations)
      transformer_for(processor).new(transformations).send(:operations)
    end

    def transformer_for(processor)
      case processor
      when :vips
        ActiveStorage::Transformers::Vips
      when :mini_magick
        ActiveStorage::Transformers::ImageMagick
      else
        raise "#{processor.inspect} is not a valid image transformer"
      end
    rescue LoadError
      ENV["BUILDKITE"] ? raise : skip("Variant processor #{processor.inspect} is not installed")
    end
end
