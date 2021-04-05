# frozen_string_literal: true

class ActiveStorage::VariantWithRecord
  attr_reader :blob, :variation

  def initialize(blob, variation)
    @blob, @variation = blob, ActiveStorage::Variation.wrap(variation)
  end

  def processed
    process
    self
  end

  def process
    transform_blob { |image| create_or_find_record(image: image) } unless processed?
  end

  def processed?
    record.present?
  end

  def image
    record&.image
  end

  delegate :key, :url, :download, to: :image, allow_nil: true

  alias_method :service_url, :url
  deprecate service_url: :url

  private
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
        ActiveRecord::Base.connected_to(role: ActiveRecord::Base.writing_role) do
          blob.variant_records.create_or_find_by!(variation_digest: variation.digest) do |record|
            record.image.attach(image)
          end
        end
    end

    def record
      @record ||= blob.variant_records.find_by(variation_digest: variation.digest)
    end
end
