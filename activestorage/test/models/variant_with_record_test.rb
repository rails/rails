# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::VariantWithRecordTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @was_tracking, ActiveStorage.track_variants = ActiveStorage.track_variants, true
  end

  teardown do
    ActiveStorage.track_variants = @was_tracking
  end

  test "generating a resized variation of a JPEG blob" do
    blob = create_file_blob(filename: "racecar.jpg")
    variant = blob.variant(resize_to_limit: [100, 100])

    assert_difference -> { blob.variant_records.count }, +1 do
      variant.processed
    end

    assert_match(/racecar\.jpg/, variant.url)
    assert_equal "racecar.jpg", variant.filename.to_s
    assert_equal "image/jpeg", variant.content_type

    image = read_image(variant.image)
    assert_equal 100, image.width
    assert_equal 67, image.height

    record = blob.variant_records.last
    assert_equal variant.variation.digest, record.variation_digest
  end

  test "serving a previously-generated resized variation of a JPEG blob" do
    blob = create_file_blob(filename: "racecar.jpg")

    assert_difference -> { blob.variant_records.count } do
      blob.variant(resize_to_limit: [100, 100]).processed
    end

    variant = blob.variant(resize_to_limit: [100, 100])

    assert_no_difference -> { blob.variant_records.count } do
      variant.processed
    end

    assert_match(/racecar\.jpg/, variant.url)

    image = read_image(variant.image)
    assert_equal 100, image.width
    assert_equal 67, image.height
  end

  test "variant of a blob is on the same service" do
    blob = create_file_blob(filename: "racecar.jpg", service_name: "local_public")
    variant = blob.variant(resize_to_limit: [100, 100]).processed

    assert_equal "local_public", variant.image.blob.service_name
  end

  test "eager loading has_one_attached record" do
    user1 = User.create!(name: "Josh")
    user2 = User.create!(name: "John")

    blob1 = directly_upload_file_blob(filename: "racecar.jpg")
    assert_difference -> { ActiveStorage::VariantRecord.count }, +1 do
      blob1.representation(resize_to_limit: [100, 100]).processed
    end

    blob2 = directly_upload_file_blob(filename: "racecar_rotated.jpg")
    assert_difference -> { ActiveStorage::VariantRecord.count }, +1 do
      blob2.representation(resize_to_limit: [100, 100]).processed
    end

    assert_no_difference -> { ActiveStorage::VariantRecord.count } do
      user1.cover_photo.attach(blob1)
      user2.cover_photo.attach(blob2)
    end

    users = User.where(id: [user1.id, user2.id])

    users.reset

    assert_no_difference -> { ActiveStorage::VariantRecord.count } do
      assert_queries(11) do
        # 11 queries:
        # users x 1
        # attachment (cover photo) x 2
        # blob for the cover photo x 2
        # variant record x 1 per blob
        # attachment x 1 per variant record
        # variant record x 1 per variant record attachment
        users.each do |u|
          rep = u.cover_photo.representation(resize_to_limit: [100, 100])
          rep.processed
          rep.key
          rep.url
        end
      end
    end

    users.reset

    assert_no_difference -> { ActiveStorage::VariantRecord.count } do
      assert_queries(6) do
        # 6 queries:
        # users x 1
        # attachment (cover photos) x 1
        # blob for the cover photo x 1
        # variant record x 1
        # attachment x 1
        # variant record x 1
        users.with_attached_cover_photo.each do |u|
          rep = u.cover_photo.representation(resize_to_limit: [100, 100])
          rep.processed
          rep.key
          rep.url
        end
      end
    end
  end

  test "eager loading has_many_attached records" do
    user = User.create!(name: "Josh")

    blob1 = directly_upload_file_blob(filename: "racecar.jpg")
    assert_difference -> { ActiveStorage::VariantRecord.count }, +1 do
      blob1.representation(resize_to_limit: [100, 100]).processed
    end

    blob2 = directly_upload_file_blob(filename: "racecar_rotated.jpg")
    assert_difference -> { ActiveStorage::VariantRecord.count }, +1 do
      blob2.representation(resize_to_limit: [100, 100]).processed
    end

    assert_no_difference -> { ActiveStorage::VariantRecord.count } do
      user.vlogs.attach(blob1)
      user.vlogs.attach(blob2)
    end

    user.reload

    assert_no_difference -> { ActiveStorage::VariantRecord.count } do
      assert_queries(9) do
        # 9 queries:
        # attachments (vlogs) x 1
        # blob x 2
        # variant record x 1 per blob
        # attachment x 1 per variant record
        # variant record x 1 per variant record attachment
        user.vlogs.each do |vlog|
          rep = vlog.representation(resize_to_limit: [100, 100])
          rep.processed
          rep.key
          rep.url
        end
      end
    end

    user.reload

    assert_no_difference -> { ActiveStorage::VariantRecord.count } do
      assert_queries(7) do
        # 7 queries:
        # attachments (vlogs) x 1
        # blob x 1
        # variant record x 1
        # attachment -> blob x 1 per variant record (so 2)
        user.vlogs.includes(blob: :variant_records).each do |vlog|
          rep = vlog.representation(resize_to_limit: [100, 100])
          rep.processed
          rep.key
          rep.url
        end
      end
    end

    user.reload

    assert_no_difference -> { ActiveStorage::VariantRecord.count } do
      assert_queries(5) do
        # 5 queries:
        # attachments (vlogs) x 1
        # blobs for the vlogs x 1
        # variant records for the blobs x 1
        # attachments for the variant records x 1
        # blobs for the attachments for the variant records x 1
        user.vlogs.includes(blob: { variant_records: { image_attachment: :blob } }).each do |vlog|
          rep = vlog.representation(resize_to_limit: [100, 100])
          rep.processed
          rep.key
          rep.url
        end
      end
    end

    user.reload

    assert_no_difference -> { ActiveStorage::VariantRecord.count } do
      assert_queries(5) do
        # 5 queries:
        # attachments (vlogs) x 1
        # blobs for the vlogs x 1
        # variant records for the blobs x 1
        # attachments for the variant records x 1
        # blobs for the attachments for the variant records x 1
        user.vlogs.with_all_variant_records.each do |vlog|
          rep = vlog.representation(resize_to_limit: [100, 100])
          rep.processed
          rep.key
          rep.url
        end
      end
    end

    user.reload

    assert_no_difference -> { ActiveStorage::VariantRecord.count } do
      assert_queries(6) do
        # 6 queries:
        # user x 1
        # attachments (vlogs) x 1
        # blobs for the vlogs x 1
        # variant records for the blobs x 1
        # attachments for the variant records x 1
        # blobs for the attachments for the variant records x 1
        User.where(id: user.id).with_attached_vlogs.each do |u|
          u.vlogs.map do |vlog|
            rep = vlog.representation(resize_to_limit: [100, 100])
            rep.processed
            rep.key
            rep.url
          end
        end
      end
    end

    user.reload

    assert_difference -> { ActiveStorage::VariantRecord.count }, +2 do
      # More queries here because we are creating a different variant.
      # The second time we load this variant, we are back down to just 3 queries.

      assert_queries(9, matcher: /SELECT/) do
        # 9 queries:
        # attachments (vlogs) initial load x 1
        # blob x 1 (gets both records)
        # variant record x 1 (gets both records)
        # 2x get blob, attachment, variant records again, this happens when loading the new blob inside `VariantWithRecord#key`
        user.vlogs.with_all_variant_records.each do |vlog|
          rep = vlog.representation(resize_to_limit: [200, 200])
          rep.processed
          rep.key
          rep.url
        end
      end

      user.reload

      assert_queries(5) do
        user.vlogs.with_all_variant_records.each do |vlog|
          rep = vlog.representation(resize_to_limit: [200, 200])
          rep.processed
          rep.key
          rep.url
        end
      end
    end
  end

  test "destroy deletes file from service" do
    blob = create_file_blob(filename: "racecar.jpg")
    variant = blob.variant(resize_to_limit: [100, 100]).processed

    assert_equal 1, ActiveStorage::VariantRecord.count
    assert blob.service.exist?(variant.key)

    variant.destroy

    assert_equal 0, ActiveStorage::VariantRecord.count
    assert_enqueued_with(job: ActiveStorage::PurgeJob, args: [variant.image.blob])
  end
end
