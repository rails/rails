# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::VariantWithRecordTest < ActiveSupport::TestCase
  setup do
    @was_tracking, ActiveStorage.track_variants = ActiveStorage.track_variants, true
  end

  teardown do
    ActiveStorage.track_variants = @was_tracking
  end

  test "generating a resized variation of a JPEG blob" do
    blob = create_file_blob(filename: "racecar.jpg")
    variant = blob.variant(resize: "100x100")

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

  test "serving a previously-generated resized variation of a JPEG blob" do
    blob = create_file_blob(filename: "racecar.jpg")

    assert_difference -> { blob.variant_records.count } do
      blob.variant(resize: "100x100").process
    end

    variant = blob.variant(resize: "100x100")

    assert_no_difference -> { blob.variant_records.count } do
      variant.process
    end

    assert_match(/racecar\.jpg/, variant.url)

    image = read_image(variant.image)
    assert_equal 100, image.width
    assert_equal 67, image.height
  end

  test "variant of a blob is on the same service" do
    blob = create_file_blob(filename: "racecar.jpg", service_name: "local_public")
    variant = blob.variant(resize: "100x100").process

    assert_equal "local_public", variant.image.blob.service_name
  end

  test "eager loading is supported" do
    user = User.create!(name: "Josh")

    blob1 = directly_upload_file_blob(filename: "racecar.jpg")
    assert_difference -> { ActiveStorage::VariantRecord.count }, +1 do
      blob1.representation(resize: "100x100").process
    end

    blob2 = directly_upload_file_blob(filename: "racecar_rotated.jpg")
    assert_difference -> { ActiveStorage::VariantRecord.count }, +1 do
      blob2.representation(resize: "100x100").process
    end

    assert_no_difference -> { ActiveStorage::VariantRecord.count } do
      user.vlogs.attach(blob1)
      user.vlogs.attach(blob2)
    end

    user.reload

    assert_no_difference -> { ActiveStorage::VariantRecord.count } do
      assert_queries(5) do
        # 5 queries:
        # attachments (vlogs) x 1
        # blob x 2
        # variant record x 2
        user.vlogs.map do |vlog|
          vlog.representation(resize: "100x100").processed
        end
      end
    end

    user.reload

    assert_no_difference -> { ActiveStorage::VariantRecord.count } do
      assert_queries(3) do
        # 3 queries:
        # attachments (vlogs) x 1
        # blob x 1
        # variant record x 1
        user.vlogs.includes(blob: :variant_records).map do |vlog|
          vlog.representation(resize: "100x100").processed
        end
      end
    end

    user.reload

    assert_no_difference -> { ActiveStorage::VariantRecord.count } do
      assert_queries(3) do
        # 3 queries:
        # attachments (vlogs) x 1
        # blob x 1
        # variant record x 1
        user.vlogs.with_all_variant_records.map do |vlog|
          vlog.representation(resize: "100x100").processed
        end
      end
    end

    user.reload

    assert_no_difference -> { ActiveStorage::VariantRecord.count } do
      assert_queries(4) do
        # 4 queries:
        # user x 1
        # attachments (vlogs) x 1
        # blob x 1
        # variant record x 1
        User.where(id: user.id).with_attached_vlogs.map do |u|
          u.vlogs.map do |vlog|
            vlog.representation(resize: "100x100").processed
          end
        end
      end
    end
  end

  test "video is invariable without custom transformer" do
    @orig_transformers = ActiveStorage.transformers
    ActiveStorage.transformers = [ActiveStorage::Transformers::ImageProcessingTransformer]

    blob = create_file_blob(filename: "video.mp4")
    assert_raises ActiveStorage::InvariableError do
      blob.variant({}).processed
    end
  ensure
    ActiveStorage.transformers = @orig_transformers
  end

  test "video is twice longer using custom transformer" do
    @orig_transformers = ActiveStorage.transformers
    ActiveStorage.transformers << FfmpegTransformer

    blob = create_file_blob(filename: "video.mp4")
    blob_metadata = extract_metadata_from(blob)
    blob_duration = blob_metadata[:duration]

    opts = '-filter_complex "[0:v]setpts=2*PTS[v];[0:a]atempo=0.5[a]" -map "[v]" -map "[a]"'
    variant = blob.variant(ffmpeg_opts: opts, format: "mp4").processed
    assert_match(/video\.mp4/, variant.url)

    variant_blob = ActiveStorage::Blob.last
    assert variant_blob.video?
    variant_metadata = extract_metadata_from(variant_blob)
    assert_in_delta blob_duration * 2, variant_metadata[:duration], 0.1
  ensure
    ActiveStorage.transformers = @orig_transformers
  end
end
