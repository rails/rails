# frozen_string_literal: true

require "test_helper"
require "database/setup"
require "minitest/mock"

class ActiveStorage::VariantTest < ActiveSupport::TestCase
  setup do
    @was_tracking, ActiveStorage.track_variants = ActiveStorage.track_variants, false
  end

  teardown do
    ActiveStorage.track_variants = @was_tracking
  end

  test "variations have the same key for different types of the same transformation" do
    blob = create_file_blob(filename: "racecar.jpg")
    variant_a = blob.variant(resize_to_limit: [100, 100])
    variant_b = blob.variant("resize_to_limit" => [100, 100])

    assert_equal variant_a.key, variant_b.key
  end

  test "resized variation of JPEG blob" do
    blob = create_file_blob(filename: "racecar.jpg")
    variant = blob.variant(resize_to_limit: [100, 100]).processed
    assert_match(/racecar\.jpg/, variant.url)

    image = read_image(variant)
    assert_equal 100, image.width
    assert_equal 67, image.height
  end

  test "resized and monochrome variation of JPEG blob" do
    blob = create_file_blob(filename: "racecar.jpg")
    variant = blob.variant(resize_to_limit: [100, 100], colourspace: "b-w").processed
    assert_match(/racecar\.jpg/, variant.url)

    image = read_image(variant)
    assert_equal 100, image.width
    assert_equal 67, image.height
    assert_match(/Gray/, image.colorspace)
  end

  test "monochrome with default variant_processor" do
    blob = create_file_blob(filename: "racecar.jpg")
    variant = blob.variant(colourspace: "b-w").processed
    image = read_image(variant)
    assert_match(/Gray/, image.colorspace)
  end

  test "disabled variation of JPEG blob" do
    blob = create_file_blob(filename: "racecar.jpg")
    variant = blob.variant(resize_to_limit: [100, 100], colourspace: "srgb").processed
    assert_match(/racecar\.jpg/, variant.url)

    image = read_image(variant)
    assert_equal 100, image.width
    assert_equal 67, image.height
    assert_match(/RGB/, image.colorspace)
  end

  test "center-weighted crop of JPEG blob using :resize_to_fill" do
    blob = create_file_blob(filename: "racecar.jpg")
    variant = blob.variant(resize_to_fill: [100, 100]).processed
    assert_match(/racecar\.jpg/, variant.url)

    image = read_image(variant)
    assert_equal 100, image.width
    assert_equal 100, image.height
  end

  test "resized variation of PSD blob" do
    blob = create_file_blob(filename: "icon.psd", content_type: "image/vnd.adobe.photoshop")
    variant = blob.variant(resize_to_limit: [20, 20]).processed
    assert_match(/icon\.png/, variant.url)

    image = read_image(variant)
    assert_equal "PNG", image.type
    assert_equal 20, image.width
    assert_equal 20, image.height
  end

  test "resized variation of ICO blob" do
    blob = create_file_blob(filename: "favicon.ico", content_type: "image/vnd.microsoft.icon")
    variant = blob.variant(resize_to_limit: [20, 20]).processed
    assert_match(/icon\.png/, variant.url)

    image = read_image(variant)
    assert_equal "PNG", image.type
    assert_equal 20, image.width
    assert_equal 20, image.height
  end

  test "resized variation of TIFF blob" do
    blob = create_file_blob(filename: "racecar.tif")
    variant = blob.variant(resize_to_limit: [50, 50]).processed
    assert_match(/racecar\.png/, variant.url)

    image = read_image(variant)
    assert_equal "PNG", image.type
    assert_equal 50, image.width
    assert_equal 33, image.height
  end

  test "resized variation of BMP blob" do
    blob = create_file_blob(filename: "colors.bmp", content_type: "image/bmp")
    variant = blob.variant(resize_to_limit: [15, 15]).processed
    assert_match(/colors\.png/, variant.url)

    image = read_image(variant)
    assert_equal "PNG", image.type
    assert_equal 15, image.width
    assert_equal 8, image.height
  end

  test "resized variation of WEBP blob" do
    blob = create_file_blob(filename: "valley.webp")
    variant = blob.variant(resize_to_limit: [50, 50]).processed
    assert_match(/valley\.webp/, variant.url)

    image = read_image(variant)
    assert_equal "WEBP", image.type
    assert_equal 50, image.width
    assert_includes [33, 34], image.height
  end

  test "optimized variation of GIF blob" do
    blob = create_file_blob(filename: "image.gif", content_type: "image/gif")

    process_variants_with :vips do
      assert_nothing_raised do
        blob.variant(saver: { optimize_gif_frames: true, optimize_gif_transparency: true }).processed
      end
    end

    process_variants_with :mini_magick do
      assert_nothing_raised do
        blob.variant(layers: "Optimize").processed
      end
    end
  end

  test "PNG variation of JPEG blob with lowercase format" do
    blob = create_file_blob(filename: "racecar.jpg")
    variant = blob.variant(format: :png).processed
    assert_equal "racecar.png", variant.filename.to_s
    assert_equal "image/png", variant.content_type
    assert_equal "PNG", read_image(variant).type
  end

  test "PNG variation of JPEG blob with uppercase format" do
    blob = create_file_blob(filename: "racecar.jpg")
    variant = blob.variant(format: "PNG").processed
    assert_equal "racecar.png", variant.filename.to_s
    assert_equal "image/png", variant.content_type
    assert_equal "PNG", read_image(variant).type
  end

  test "variation of invariable blob" do
    assert_raises ActiveStorage::InvariableError, match: /blob with ID=\d+ and content_type=application\/pdf/ do
      create_file_blob(filename: "report.pdf", content_type: "application/pdf").variant(resize_to_limit: [100, 100])
    end
  end

  test "url doesn't grow in length despite long variant options" do
    process_variants_with :mini_magick do
      blob = create_file_blob(filename: "racecar.jpg")
      variant = blob.variant(font: "a" * 10_000).processed
      assert_operator variant.url.length, :<, 785
    end
  end

  test "thumbnail variation of JPEG blob processed with VIPS" do
    process_variants_with :vips do
      blob = create_file_blob(filename: "racecar.jpg")
      variant = blob.variant(thumbnail_image: 100).processed

      image = read_image(variant)
      assert_equal 100, image.width
      assert_equal 67, image.height
    end
  end

  test "thumbnail variation of extensionless GIF blob processed with VIPS" do
    process_variants_with :vips do
      blob = ActiveStorage::Blob.create_and_upload!(io: file_fixture("image.gif").open, filename: "image", content_type: "image/gif")
      variant = blob.variant(resize_to_fit: [100, 100]).processed

      image = read_image(variant)
      assert_equal "image.gif", variant.filename.to_s
      assert_equal "image/gif", variant.content_type
      assert_equal "GIF", image.type
      assert_equal 100, image.width
      assert_equal 100, image.height
    end
  end

  test "passes content_type on upload" do
    blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")

    mock_upload = lambda do |_, _, options = {}|
      assert_equal "image/jpeg", options[:content_type]
    end

    blob.service.stub(:upload, mock_upload) do
      blob.variant(resize_to_limit: [100, 100]).processed
    end
  end

  test "content_type not recognized by marcel isn't included as variable" do
    blob = create_file_blob(filename: "racecar.jpg")

    # image/jpg is not recognized by marcel (image/jpeg is correct)
    blob.update(content_type: "image/jpg")

    assert_raises(ActiveStorage::InvariableError) do
      blob.variant(resize_to_limit: [100, 100])
    end

    assert_nil blob.send(:format)
    assert_equal :png, blob.send(:default_variant_format)
  end

  test "variations with dangerous argument string raise UnsupportedImageProcessingArgument" do
    process_variants_with :mini_magick do
      blob = create_file_blob(filename: "racecar.jpg")
      assert_raise(ActiveStorage::Transformers::ImageProcessingTransformer::UnsupportedImageProcessingArgument) do
        blob.variant(resize: "-PaTh /tmp/file.erb").processed
      end
    end
  end

  test "variations with dangerous argument array raise UnsupportedImageProcessingArgument" do
    process_variants_with :mini_magick do
      blob = create_file_blob(filename: "racecar.jpg")
      assert_raise(ActiveStorage::Transformers::ImageProcessingTransformer::UnsupportedImageProcessingArgument) do
        blob.variant(resize: [123, "-write", "/tmp/file.erb"]).processed
      end
    end
  end

  test "variations with dangerous argument in a nested array raise UnsupportedImageProcessingArgument" do
    process_variants_with :mini_magick do
      blob = create_file_blob(filename: "racecar.jpg")
      assert_raise(ActiveStorage::Transformers::ImageProcessingTransformer::UnsupportedImageProcessingArgument) do
        blob.variant(resize: [123, ["-write", "/tmp/file.erb"], "/tmp/file.erb"]).processed
      end

      assert_raise(ActiveStorage::Transformers::ImageProcessingTransformer::UnsupportedImageProcessingArgument) do
        blob.variant(resize: [123, { "-write /tmp/file.erb": "something" }, "/tmp/file.erb"]).processed
      end
    end
  end

  test "variations with dangerous argument hash raise UnsupportedImageProcessingArgument" do
    process_variants_with :mini_magick do
      blob = create_file_blob(filename: "racecar.jpg")
      assert_raise(ActiveStorage::Transformers::ImageProcessingTransformer::UnsupportedImageProcessingArgument) do
        blob.variant(saver: { "-write": "/tmp/file.erb" }).processed
      end
    end
  end

  test "variations with dangerous argument in a nested hash raise UnsupportedImageProcessingArgument" do
    process_variants_with :mini_magick do
      blob = create_file_blob(filename: "racecar.jpg")
      assert_raise(ActiveStorage::Transformers::ImageProcessingTransformer::UnsupportedImageProcessingArgument) do
        blob.variant(saver: { "something": { "-write": "/tmp/file.erb" } }).processed
      end

      assert_raise(ActiveStorage::Transformers::ImageProcessingTransformer::UnsupportedImageProcessingArgument) do
        blob.variant(saver: { "something": ["-write", "/tmp/file.erb"] }).processed
      end
    end
  end

  test "variations with unsupported methods raise UnsupportedImageProcessingMethod" do
    process_variants_with :mini_magick do
      blob = create_file_blob(filename: "racecar.jpg")
      assert_raise(ActiveStorage::Transformers::ImageProcessingTransformer::UnsupportedImageProcessingMethod) do
        blob.variant(system: "touch /tmp/dangerous").processed
      end
    end
  end

  test "destroy deletes file from service" do
    blob = create_file_blob(filename: "racecar.jpg")
    variant = blob.variant(resize_to_limit: [100, 100]).processed

    assert_changes -> { blob.service.exist?(variant.key) }, from: true, to: false do
      variant.destroy
    end
  end

  private
    def process_variants_with(processor)
      previous_transformer = ActiveStorage.variant_transformer
      ActiveStorage.variant_transformer =
        case processor
        when :vips
          ActiveStorage::Transformers::Vips
        when :mini_magick
          ActiveStorage::Transformers::ImageMagick
        else
          raise "#{processor.inspect} is not a valid image transformer"
        end

      yield
    rescue LoadError
      ENV["BUILDKITE"] ? raise : skip("Variant processor #{processor.inspect} is not installed")
    ensure
      ActiveStorage.variant_transformer = previous_transformer
    end
end
