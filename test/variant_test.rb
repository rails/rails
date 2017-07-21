require "test_helper"
require "database/setup"
require "active_storage/variant"

class ActiveStorage::VariantTest < ActiveSupport::TestCase
  setup do
    @blob = create_image_blob filename: "racecar.jpg"
  end

  test "resized variation" do
    variant = @blob.variant(resize: "100x100").processed

    assert_match /racecar.jpg/, variant.url    
    assert_same_image "racecar-100x100.jpg", variant    
  end

  test "resized and monochrome variation" do
    variant = @blob.variant(resize: "100x100", monochrome: true).processed

    assert_match /racecar.jpg/, variant.url
    assert_same_image "racecar-100x100-monochrome.jpg", variant    
  end

  private
    def assert_same_image(fixture_filename, variant)
      assert_equal \
        File.binread(File.expand_path("../fixtures/files/#{fixture_filename}", __FILE__)),
        File.binread(variant.service.send(:path_for, variant.key))
    end
end
