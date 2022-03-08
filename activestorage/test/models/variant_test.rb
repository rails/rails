# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::VariantTest < ActiveSupport::TestCase
  test "variations with unsupported methods raise UnsupportedImageProcessingMethod" do
    blob = create_file_blob(filename: "racecar.jpg")
    assert_raise(ActiveStorage::Variation::UnsupportedImageProcessingMethod) do
      blob.variant(system: "touch /tmp/dangerous").processed
    end
  end

  test "variations with unsupported methods in combine_options raise UnsupportedImageProcessingMethod" do
    blob = create_file_blob(filename: "racecar.jpg")

    assert_raise(ActiveStorage::Variation::UnsupportedImageProcessingMethod) do
      blob.variant(combine_options: {
        gravity: "center",
        write: "/tmp/danger",
        crop: "100x10000",
      }).processed
    end
  end

  test "variations with dangerous argument in combine_options raise UnsupportedImageProcessingArgument" do
    blob = create_file_blob(filename: "racecar.jpg")

    assert_raise(ActiveStorage::Variation::UnsupportedImageProcessingArgument) do
      blob.variant(combine_options: {
        gravity: "center",
        resize: "-write /tmp/danger",
        crop: "100x10000",
      }).processed
    end
  end

  test "variations with dangerous argument string raise UnsupportedImageProcessingArgument" do
    blob = create_file_blob(filename: "racecar.jpg")
    assert_raise(ActiveStorage::Variation::UnsupportedImageProcessingArgument) do
      blob.variant(resize: "-PaTh /tmp/file.erb").processed
    end
  end

  test "variations with dangerous argument array raise UnsupportedImageProcessingArgument" do
    blob = create_file_blob(filename: "racecar.jpg")
    assert_raise(ActiveStorage::Variation::UnsupportedImageProcessingArgument) do
      blob.variant(resize: [123, "-write", "/tmp/file.erb"]).processed
    end
  end

  test "variations with dangerous argument in a nested array raise UnsupportedImageProcessingArgument" do
    blob = create_file_blob(filename: "racecar.jpg")
    assert_raise(ActiveStorage::Variation::UnsupportedImageProcessingArgument) do
      blob.variant(resize: [123, ["-write", "/tmp/file.erb"], "/tmp/file.erb"]).processed
    end

    assert_raise(ActiveStorage::Variation::UnsupportedImageProcessingArgument) do
      blob.variant(resize: [123, {"-write /tmp/file.erb": "something"}, "/tmp/file.erb"]).processed
    end
  end

  test "variations with dangerous argument hash raise UnsupportedImageProcessingArgument" do
    blob = create_file_blob(filename: "racecar.jpg")
    assert_raise(ActiveStorage::Variation::UnsupportedImageProcessingArgument) do
      blob.variant(saver: {"-write": "/tmp/file.erb"}).processed
    end
  end

  test "variations with dangerous argument in a nested hash raise UnsupportedImageProcessingArgument" do
    blob = create_file_blob(filename: "racecar.jpg")
    assert_raise(ActiveStorage::Variation::UnsupportedImageProcessingArgument) do
      blob.variant(saver: {"something": {"-write": "/tmp/file.erb"}}).processed
    end

    assert_raise(ActiveStorage::Variation::UnsupportedImageProcessingArgument) do
      blob.variant(saver: {"something": ["-write", "/tmp/file.erb"]}).processed
    end
  end

  test "resized variation of JPEG blob" do
    blob = create_file_blob(filename: "racecar.jpg")
    variant = blob.variant(resize: "100x100").processed
    assert_match(/racecar\.jpg/, variant.service_url)

    image = read_image(variant)
    assert_equal 100, image.width
    assert_equal 67, image.height
  end

  test "resized and monochrome variation of JPEG blob" do
    blob = create_file_blob(filename: "racecar.jpg")
    variant = blob.variant(resize: "100x100", monochrome: true).processed
    assert_match(/racecar\.jpg/, variant.service_url)

    image = read_image(variant)
    assert_equal 100, image.width
    assert_equal 67, image.height
    assert_match(/Gray/, image.colorspace)
  end

  test "center-weighted crop of JPEG blob" do
    blob = create_file_blob(filename: "racecar.jpg")
    variant = blob.variant(combine_options: {
      gravity: "center",
      resize: "100x100^",
      crop: "100x100+0+0",
    }).processed
    assert_match(/racecar\.jpg/, variant.service_url)

    image = read_image(variant)
    assert_equal 100, image.width
    assert_equal 100, image.height
  end

  test "resized variation of PSD blob" do
    blob = create_file_blob(filename: "icon.psd", content_type: "image/vnd.adobe.photoshop")
    variant = blob.variant(resize: "20x20").processed
    assert_match(/icon\.png/, variant.service_url)

    image = read_image(variant)
    assert_equal "PNG", image.type
    assert_equal 20, image.width
    assert_equal 20, image.height
  end

  test "resized variation of ICO blob" do
    blob = create_file_blob(filename: "favicon.ico", content_type: "image/vnd.microsoft.icon")
    variant = blob.variant(resize: "20x20").processed
    assert_match(/icon\.png/, variant.service_url)

    image = read_image(variant)
    assert_equal "PNG", image.type
    assert_equal 20, image.width
    assert_equal 20, image.height
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

  test "service_url doesn't grow in length despite long variant options" do
    blob = create_file_blob(filename: "racecar.jpg")
    variant = blob.variant(font: "a" * 10_000).processed
    assert_operator variant.service_url.length, :<, 726
  end
end
