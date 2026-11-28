# frozen_string_literal: true

# Active Storage \Variant With Record
# ===================================
#
# Like an ActiveStorage::Variant, but keeps detail about the variant in the database as an
# ActiveStorage::VariantRecord. This is used if `ActiveStorage.track_variants` is enabled.
class ActiveStorage::VariantWithRecord
  include ActiveStorage::Blob::Servable

  attr_reader :blob, :variation
  delegate :service, to: :blob
  delegate :content_type, to: :variation

  def initialize(blob, variation)
    @blob, @variation = blob, ActiveStorage::Variation.wrap(variation)
  end

  def processed
    process unless processed?
    self
  end

  def image
    record&.image
  end

  def filename
    ActiveStorage::Filename.new "#{blob.filename.base}.#{variation.format.downcase}"
  end

  # Destroys record and deletes file from service.
  def destroy
    record&.destroy
  end

  delegate :key, :url, :download, to: :image, allow_nil: true

  # Returns true if the variant has already been processed and stored.
  def processed?
    record.present?
  end

  private
    def process
      transform_blob { |image| create_or_find_record(image: image) }
    end

    def transform_blob
      blob.open do |input|
        variation.transform(input) do |output|
          yield io: output, filename: "#{blob.filename.base}.#{variation.format.downcase}",
            content_type: variation.content_type, service_name: blob.service.name
        end
      end
    end

    def create_or_find_record(image:)
      ActiveRecord::Base.connected_to(role: ActiveRecord.writing_role) do
        image_blob = ActiveStorage::Blob.build_after_unfurling(**image)
        attachment = nil

        begin
          upload_image(image_blob, image.fetch(:io))

          @record = blob.variant_records.create_or_find_by!(variation_digest: variation.digest) do |record|
            record.image.attach(image_blob)
            attachment = record.image.attachment
            # The file is on the primary. Run upload callbacks only if this attachment commits.
            attachment.pending_upload = true
          end
        ensure
          if image_blob.persisted?
            ActiveStorage::Blob.with_connection { |connection| finish_upload(connection, image_blob, attachment) }
          end
        end
      end
    end

    def upload_image(image_blob, io)
      image_blob.local_io = io
      image_blob.analyze_without_saving unless ActiveStorage::Attachment.analyze_lazily?(ActiveStorage::VariantRecord, :image)
      image_blob.save!
      io.rewind
      image_blob.upload_without_unfurling(io, service: image_blob.service.primary_service)
    ensure
      image_blob.local_io = nil
    end

    def finish_upload(connection, image_blob, attachment)
      transaction = connection.current_transaction
      if transaction.open?
        transaction.after_rollback { rollback_upload(image_blob, attachment) }
        # A savepoint inside a non-joinable transaction can run its commit callbacks
        # before the enclosing transaction commits. Follow it to the outermost commit.
        transaction.after_commit { finish_upload(connection, image_blob, attachment) }
      elsif attachment&.persisted?
        attachment.run_upload_callbacks
      else
        image_blob.purge_later
      end
    end

    def rollback_upload(image_blob, attachment)
      if attachment
        blob.variant_records.target.delete(attachment.record)
        @record = nil if @record.equal?(attachment.record)
      end

      # Even a queue adapter that cannot schedule the deletion retry must let
      # the application's remaining rollback callbacks run.
      context = { service_name: image_blob.service_name, key: image_blob.key }
      ActiveSupport.error_reporter.handle(StandardError, NotImplementedError, source: "active_storage", context: context) do
        ActiveStorage::DeleteVariantUploadJob.perform_now(image_blob.service_name, image_blob.key)
      end
    end

    def record
      @record ||= if blob.variant_records.loaded?
        blob.variant_records.find { |v| v.variation_digest == variation.digest }
      else
        blob.variant_records.find_by(variation_digest: variation.digest)
      end
    end
end
