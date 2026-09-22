# frozen_string_literal: true

# = Active Storage \Variant With Record
#
# Like an ActiveStorage::Variant, but keeps detail about the variant in the database as an
# ActiveStorage::VariantRecord. This is used if +ActiveStorage.track_variants+ is enabled.
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

  # Process the variant from a local io, avoiding a download from the service.
  # This is an optimization for when the original file is still available locally
  # (e.g., during the initial upload flow).
  def process_from_io(io) # :nodoc:
    return if processed?

    variation.transform(io) do |output|
      create_or_find_record(image: {
        io: output,
        filename: "#{blob.filename.base}.#{variation.format.downcase}",
        content_type: variation.content_type,
        service_name: blob.service.name
      })
    end
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
        # Upload first so the variant record remains an availability marker.
        image_blob = ActiveStorage::Blob.build_after_unfurling(**image)

        begin
          image_blob.local_io = image.fetch(:io)
          image_blob.analyze_without_saving unless ActiveStorage.analyze == :lazily
          image_blob.save!
          image_blob.class.current_transaction.after_rollback { image_blob.delete }
          image_blob.local_io.rewind
          image_blob.upload_without_unfurling(image_blob.local_io)
        rescue
          image_blob.class.current_transaction.after_commit { image_blob.purge_later } if image_blob.persisted?
          raise
        ensure
          image_blob.local_io = nil
        end

        image_blob_attached = false
        begin
          @record =
            blob.variant_records.create_or_find_by!(variation_digest: variation.digest) do |record|
              record.image.attach(image_blob)
            end.tap do |record|
              image_blob_attached = record.image_blob == image_blob
            end
        ensure
          image_blob.class.current_transaction.after_commit { image_blob.purge_later } unless image_blob_attached
        end
        @record
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
