# frozen_string_literal: true

# = Active Storage \Variant With Record
#
# Like an ActiveStorage::Variant, but keeps detail about the variant in the database as an
# ActiveStorage::VariantRecord. This is only used if +ActiveStorage.track_variants+ is enabled.
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

  private
    def processed?
      record.present?
    end

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
      @record =
        ActiveRecord::Base.connected_to(role: ActiveRecord.writing_role) do
          blob.variant_records.create_or_find_by!(variation_digest: variation.digest) do |record|
            record.image.attach(image)
          end
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
