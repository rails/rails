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
    variant_a = blob.variant(resize: "100x100")
    variant_b = blob.variant("resize" => "100x100")

    assert_equal variant_a.key, variant_b.key
  end

  test "resized variation of JPEG blob" do
    blob = create_file_blob(filename: "racecar.jpg")
    variant = blob.variant(resize: "100x100").processed
    assert_match(/racecar\.jpg/, variant.url)

    image = read_image(variant)
    assert_equal 100, image.width
    assert_equal 67, image.height
  end

  test "resized and monochrome variation of JPEG blob" do
    blob = create_file_blob(filename: "racecar.jpg")
    variant = blob.variant(resize: "100x100", monochrome: true).processed
    assert_match(/racecar\.jpg/, variant.url)

    image = read_image(variant)
    assert_equal 100, image.width
    assert_equal 67, image.height
    assert_match(/Gray/, image.colorspace)
  end

  test "monochrome with default variant_processor" do
    ActiveStorage.variant_processor = nil

    blob = create_file_blob(filename: "racecar.jpg")
    variant = blob.variant(monochrome: true).processed
    image = read_image(variant)
    assert_match(/Gray/, image.colorspace)
  ensure
    ActiveStorage.variant_processor = :mini_magick
  end

  test "disabled variation of JPEG blob" do
    blob = create_file_blob(filename: "racecar.jpg")
    variant = blob.variant(resize: "100x100", monochrome: false).processed
    assert_match(/racecar\.jpg/, variant.url)

    image = read_image(variant)
    assert_equal 100, image.width
    assert_equal 67, image.height
    assert_match(/RGB/, image.colorspace)
  end

  test "disabled variation of JPEG blob with :combine_options" do
    blob = create_file_blob(filename: "racecar.jpg")
    variant = ActiveSupport::Deprecation.silence do
      blob.variant(combine_options: {
        resize: "100x100",
        monochrome: false
      }).processed
    end
    assert_match(/racecar\.jpg/, variant.url)

    image = read_image(variant)
    assert_equal 100, image.width
    assert_equal 67, image.height
    assert_match(/RGB/, image.colorspace)
  end

  test "disabled variation using :combine_options" do
    ActiveStorage.variant_processor = nil
    blob = create_file_blob(filename: "racecar.jpg")
    variant = ActiveSupport::Deprecation.silence do
      blob.variant(combine_options: {
        crop: "100x100+0+0",
        monochrome: false
      }).processed
    end
    assert_match(/racecar\.jpg/, variant.url)

    image = read_image(variant)
    assert_equal 100, image.width
    assert_equal 100, image.height
    assert_match(/RGB/, image.colorspace)
  ensure
    ActiveStorage.variant_processor = :mini_magick
  end

  test "center-weighted crop of JPEG blob using :combine_options" do
    ActiveStorage.variant_processor = nil
    blob = create_file_blob(filename: "racecar.jpg")
    variant = ActiveSupport::Deprecation.silence do
      blob.variant(combine_options: {
        gravity: "center",
        resize: "100x100^",
        crop: "100x100+0+0",
      }).processed
    end
    assert_match(/racecar\.jpg/, variant.url)

    image = read_image(variant)
    assert_equal 100, image.width
    assert_equal 100, image.height
  ensure
    ActiveStorage.variant_processor = :mini_magick
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
    variant = blob.variant(resize: "20x20").processed
    assert_match(/icon\.png/, variant.url)

    image = read_image(variant)
    assert_equal "PNG", image.type
    assert_equal 20, image.width
    assert_equal 20, image.height
  end

  test "resized variation of ICO blob" do
    blob = create_file_blob(filename: "favicon.ico", content_type: "image/vnd.microsoft.icon")
    variant = blob.variant(resize: "20x20").processed
    assert_match(/icon\.png/, variant.url)

    image = read_image(variant)
    assert_equal "PNG", image.type
    assert_equal 20, image.width
    assert_equal 20, image.height
  end

  test "resized variation of TIFF blob" do
    blob = create_file_blob(filename: "racecar.tif")
    variant = blob.variant(resize: "50x50").processed
    assert_match(/racecar\.png/, variant.url)

    image = read_image(variant)
    assert_equal "PNG", image.type
    assert_equal 50, image.width
    assert_equal 33, image.height
  end

  test "resized variation of BMP blob" do
    blob = create_file_blob(filename: "colors.bmp", content_type: "image/bmp")
    variant = blob.variant(resize: "15x15").processed
    assert_match(/colors\.png/, variant.url)

    image = read_image(variant)
    assert_equal "PNG", image.type
    assert_equal 15, image.width
    assert_equal 8, image.height
  end

  test "optimized variation of GIF blob" do
    blob = create_file_blob(filename: "image.gif", content_type: "image/gif")

    assert_nothing_raised do
      blob.variant(layers: "Optimize").processed
    end
  end

  test "variation of invariable blob" do
    assert_raises ActiveStorage::InvariableError do
      create_file_blob(filename: "report.pdf", content_type: "application/pdf").variant(resize: "100x100")
    end
  end

  test "url doesn't grow in length despite long variant options" do
    blob = create_file_blob(filename: "racecar.jpg")
    variant = blob.variant(font: "a" * 10_000).processed
    assert_operator variant.url.length, :<, 785
  end

  test "works for vips processor" do
    ActiveStorage.variant_processor = :vips
    blob = create_file_blob(filename: "racecar.jpg")
    variant = blob.variant(thumbnail_image: 100).processed

    image = read_image(variant)
    assert_equal 100, image.width
    assert_equal 67, image.height
  rescue LoadError
    # libvips not installed
  ensure
    ActiveStorage.variant_processor = :mini_magick
  end

  test "passes content_type on upload" do
    blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")

    mock_upload = lambda do |_, _, options = {}|
      assert_equal "image/jpeg", options[:content_type]
    end

    blob.service.stub(:upload, mock_upload) do
      blob.variant(resize: "100x100").processed
    end
  end
end
