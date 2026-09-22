# frozen_string_literal: true

require "test_helper"
require "database/setup"
require "active_support/core_ext/object/with"

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

  test "variant record is not visible until its image has been uploaded" do
    blob = create_file_blob(filename: "racecar.jpg")
    transformations = { resize_to_limit: [100, 100] }
    variant = blob.variant(transformations)
    upload = blob.service.method(:upload)
    upload_observed = false

    blob.service.stub(:upload, ->(*args, **options) do
      upload_observed = true
      assert_not blob.variant(transformations).processed?
      upload.call(*args, **options)
    end) do
      variant.processed
    end

    assert upload_observed
    assert variant.processed?
    assert blob.service.exist?(variant.key)
  end

  test "failed variant upload can be retried" do
    blob = create_file_blob(filename: "racecar.jpg")
    variant = blob.variant(resize_to_limit: [100, 100])
    upload_error = Class.new(StandardError)

    ActiveStorage::PurgeJob.with(enqueue_after_transaction_commit: false) do
      assert_enqueued_with(job: ActiveStorage::PurgeJob) do
        ActiveStorage::Blob.transaction(requires_new: true) do
          assert_no_difference -> { blob.variant_records.count } do
            blob.service.stub(:upload, ->(*, **) { raise upload_error }) do
              assert_raises(upload_error) { variant.processed }
            end
          end

          assert_no_enqueued_jobs only: ActiveStorage::PurgeJob
        end
      end
    end

    assert_not variant.processed?

    assert_difference -> { blob.variant_records.count }, +1 do
      variant.processed
    end

    assert variant.processed?
    assert blob.service.exist?(variant.key)
  end

  test "uploaded image is purged when variant record creation fails" do
    blob = create_file_blob(filename: "racecar.jpg")
    variant = blob.variant(resize_to_limit: [100, 100])
    variant_records = blob.variant_records
    record_error = Class.new(StandardError)

    blob.stub(:variant_records, variant_records) do
      variant_records.stub(:create_or_find_by!, ->(*) { raise record_error }) do
        assert_raises(record_error) { variant.processed }
      end
    end

    image_blob = ActiveStorage::Blob.order(:id).last
    assert blob.service.exist?(image_blob.key)
    assert_enqueued_with(job: ActiveStorage::PurgeJob, args: [image_blob])

    perform_enqueued_jobs(only: ActiveStorage::PurgeJob)
    assert_not blob.service.exist?(image_blob.key)
    assert_not ActiveStorage::Blob.exists?(image_blob.id)
  end

  test "uploaded image is deleted when an enclosing transaction rolls back" do
    blob = create_file_blob(filename: "racecar.jpg")
    transformations = { resize_to_limit: [100, 100] }
    upload = blob.service.method(:upload)
    uploaded_key = nil

    ActiveStorage::Blob.transaction(requires_new: true) do
      blob.service.stub(:upload, ->(key, *args, **options) do
        uploaded_key = key
        upload.call(key, *args, **options)
      end) do
        blob.variant(transformations).processed
      end

      assert blob.service.exist?(uploaded_key)
      raise ActiveRecord::Rollback
    end

    assert_not blob.service.exist?(uploaded_key)
    assert_not blob.variant(transformations).processed?
  end

  test "concurrent processing keeps one variant record and purges the unused image" do
    blob = create_file_blob(filename: "racecar.jpg")
    transformations = { resize_to_limit: [100, 100] }
    variant = blob.variant(transformations)
    concurrent_variant = blob.variant(transformations)
    upload = blob.service.method(:upload)
    concurrent_variant_processed = false

    ActiveStorage::PurgeJob.with(enqueue_after_transaction_commit: false) do
      assert_enqueued_with(job: ActiveStorage::PurgeJob) do
        ActiveStorage::Blob.transaction(requires_new: true) do
          blob.service.stub(:upload, ->(*args, **options) do
            unless concurrent_variant_processed
              concurrent_variant_processed = true
              concurrent_variant.processed
            end
            upload.call(*args, **options)
          end) do
            variant.processed
          end

          assert_no_enqueued_jobs only: ActiveStorage::PurgeJob
        end
      end
    end

    assert_difference -> { ActiveStorage::Blob.count }, -1 do
      perform_enqueued_jobs(only: ActiveStorage::PurgeJob)
    end

    assert_equal 1, blob.variant_records.count
    assert_equal concurrent_variant.key, variant.key
    assert blob.service.exist?(variant.key)
  end

  uses_transaction :test_concurrent_processing_with_separate_database_connections
  test "concurrent processing with separate database connections" do
    Dir.mktmpdir("active_storage_variant_concurrency") do |directory|
      handler = ActiveRecord::ConnectionAdapters::ConnectionHandler.new

      ActiveRecord::Base.with(connection_handler: handler) do
        # Separate connections need a shared database instead of the usual :memory: database.
        pool = ActiveRecord::Base.establish_connection(
          adapter: "sqlite3", database: File.join(directory, "variants.sqlite3"), timeout: 5000
        )
        pool.migration_context.migrate

        blob = create_file_blob(filename: "racecar.jpg")
        transformations = { resize_to_limit: [100, 100] }
        upload = blob.service.method(:upload)
        uploads = Queue.new
        ready = Concurrent::CountDownLatch.new(2)
        upload_allowed = Concurrent::Event.new
        threads = []

        blob.service.stub(:upload, ->(key, *args, **options) do
          uploads << [key, pool.active_connection]
          ready.count_down
          raise "Timed out waiting to upload variants" unless upload_allowed.wait(10)
          upload.call(key, *args, **options)
        end) do
          2.times do
            threads << Thread.new do
              Thread.current.report_on_exception = false
              ActiveRecord::Base.with(connection_handler: handler) do
                pool.with_connection do
                  ActiveStorage::Blob.find(blob.id).variant(transformations).processed
                end
              end
            end
          end

          assert ready.wait(10), "Timed out waiting for both variant uploads"
          pending_uploads = 2.times.map { uploads.pop }
          assert_equal 2, pending_uploads.map(&:last).uniq.size
          assert_empty blob.variant_records.reload
          assert_not blob.variant(transformations).processed?

          upload_allowed.set
          threads.each do |thread|
            assert thread.join(15), "Timed out waiting for variant processing"
          end
          variants = threads.map(&:value)

          assert_equal 1, blob.variant_records.count
          assert_equal variants.first.image.record_id, variants.last.image.record_id
          assert_equal variants.first.key, variants.last.key

          uploaded_keys = pending_uploads.map(&:first)
          uploaded_keys.each { |key| assert blob.service.exist?(key) }
          unused_key = (uploaded_keys - [variants.first.key]).sole
          unused_blob = ActiveStorage::Blob.find_by!(key: unused_key)
          assert_enqueued_jobs 1, only: ActiveStorage::PurgeJob
          assert_enqueued_with(job: ActiveStorage::PurgeJob, args: [unused_blob])

          assert_difference -> { ActiveStorage::Blob.count }, -1 do
            perform_enqueued_jobs(only: ActiveStorage::PurgeJob)
          end

          assert_not ActiveStorage::Blob.exists?(unused_blob.id)
          assert_not blob.service.exist?(unused_key)
          assert blob.service.exist?(variants.first.key)
          assert blob.service.exist?(blob.key)
        ensure
          upload_allowed.set
          threads.each { |thread| thread.kill if thread.alive? }
          threads.each { |thread| thread.join unless thread.status.nil? }
        end
      ensure
        pool&.disconnect!
      end
    end
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
      assert_queries_count(11) do
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
      assert_queries_count(6) do
        # 6 queries:
        # attachment (cover photos) x 1
        # blob for the cover photo x 1
        # variant record x 1
        # preview_image_attachments for non-images
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

  def find_keys_for_representation(filename)
    user = User.create!(name: "Justin")

    10.times do
      blob = directly_upload_file_blob(filename: filename)
      user.highlights_with_variants.attach(blob)
    end

    # Force the processing
    user.highlights_with_variants.each do |highlight|
      highlight.representation(:thumb).processed.key
    end

    highlights = User.with_attached_highlights_with_variants.find_by(name: "Justin").highlights_with_variants.to_a

    assert_queries_count(0) do
      highlights.each do |highlight|
        highlight.representation(:thumb).key
      end
    end
  end

  def test_with_attached_image_variant_no_n_plus_1
    find_keys_for_representation "racecar.jpg"
  end

  def test_with_attached_video_variant_no_n_plus_1
    find_keys_for_representation "video.mp4"
  end

  def test_no_n_plus_1_with_all_variant_records_on_attached_video
    user = User.create!(name: "Justin")

    10.times do
      blob = directly_upload_file_blob(filename: "video.mp4")
      user.highlights_with_variants.attach(blob)
    end

    # Force the processing
    user.highlights_with_variants.each do |highlight|
      highlight.representation(:thumb).processed.key
    end

    user.reload

    highlights = user.highlights_with_variants.with_all_variant_records.to_a

    assert_queries_count(0) do
      highlights.each do |highlight|
        highlight.representation(:thumb).key
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
      assert_queries_count(9) do
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
      assert_queries_count(7) do
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
      assert_queries_count(5) do
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
      assert_queries_count(6) do
        # 6 queries:
        # attachments (vlogs) x 1
        # blobs for the vlogs x 1
        # variant records for the blobs x 1
        # preview_image_attachments for non-images
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
      assert_queries_count(7) do
        # 7 queries:
        # user x 1
        # attachments (vlogs) x 1
        # blobs for the vlogs x 1
        # variant records for the blobs x 1
        # preview_image_attachments for non-images
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

      assert_queries_match(/SELECT/i, count: 10) do
        # 10 queries:
        # attachments (vlogs) initial load x 1
        # blob x 1 (gets both records)
        # variant record x 1 (gets both records)
        # preview_image_attachments for non-images
        # 2x get blob, attachment, variant records again, this happens when loading the new blob inside `VariantWithRecord#key`
        user.vlogs.with_all_variant_records.each do |vlog|
          rep = vlog.representation(resize_to_limit: [200, 200])
          rep.processed
          rep.key
          rep.url
        end
      end

      user.reload

      assert_queries_count(6) do
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
