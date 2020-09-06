# frozen_string_literal: true

require 'test_helper'
require 'database/setup'

class ActiveStorage::VariantWithRecordTest < ActiveSupport::TestCase
  setup do
    @was_tracking, ActiveStorage.track_variants = ActiveStorage.track_variants, true
  end

  teardown do
    ActiveStorage.track_variants = @was_tracking
  end

  test 'generating a resized variation of a JPEG blob' do
    blob = create_file_blob(filename: 'racecar.jpg')
    variant = blob.variant(resize: '100x100')

    assert_difference -> { blob.variant_records.count }, +1 do
      variant.process
    end

    assert_match(/racecar\.jpg/, variant.url)

    image = read_image(variant.image)
    assert_equal 100, image.width
    assert_equal 67, image.height

    record = blob.variant_records.last
    assert_equal variant.variation.digest, record.variation_digest
  end

  test 'serving a previously-generated resized variation of a JPEG blob' do
    blob = create_file_blob(filename: 'racecar.jpg')

    assert_difference -> { blob.variant_records.count } do
      blob.variant(resize: '100x100').process
    end

    variant = blob.variant(resize: '100x100')

    assert_no_difference -> { blob.variant_records.count } do
      variant.process
    end

    assert_match(/racecar\.jpg/, variant.url)

    image = read_image(variant.image)
    assert_equal 100, image.width
    assert_equal 67, image.height
  end

  test 'variant of a blob is on the same service' do
    blob = create_file_blob(filename: 'racecar.jpg', service_name: 'local_public')
    variant = blob.variant(resize: '100x100').process

    assert_equal 'local_public', variant.image.blob.service_name
  end
end
