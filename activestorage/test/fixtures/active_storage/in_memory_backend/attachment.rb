# frozen_string_literal: true

module ActiveStorage::InMemoryBackend
  class Attachment
    include Store

    attr_accessor :record_type, :record_id, :name, :blob_id, :pending_upload, :immediate_variants_processed

    def initialize(attributes = {})
      super
      self.record = attributes.delete(:record) if attributes.key?(:record)
      self.blob = attributes.delete(:blob) if attributes.key?(:blob)
      assign_attributes(attributes)
    end

    def record=(record)
      @record = record
      self.record_type = ActiveStorage::Attached::Changes.polymorphic_name(record)
      self.record_id = record.id
    end

    def blob=(blob)
      @blob = blob
      self.blob_id = blob&.id
    end

    def record
      @record ||= record_type.constantize.find(record_id)
    end

    def blob
      @blob ||= Blob.find(blob_id)
    end

    def assign_attributes(attributes)
      self.blob = attributes.delete(:blob) if attributes.key?(:blob)
      self.record = attributes.delete(:record) if attributes.key?(:record)
      super
    end

    def save
      was_new_record = new_record?
      self.record_id ||= record&.id
      self.blob_id ||= blob&.id
      super.tap do
        run_upload_callbacks if was_new_record && !pending_upload
      end
    end

    def uploaded(io:)
      blob.local_io = io
      blob.analyze_without_saving unless blob.analyzed? || skip_later_analysis?
      io.rewind if io.respond_to?(:rewind)
      blob.upload_without_unfurling(io)
      blob.save! if blob.persisted?
      blob.mirror_later
      blob.analyze_later unless blob.analyzed? || skip_later_analysis?
    ensure
      blob.local_io = nil
    end

    def purge
      self.class.transaction do
        delete
        touch_record
      end
      blob&.purge
    end

    def purge_later
      self.class.transaction do
        delete
        touch_record
      end
      blob&.purge_later
    end

    def signed_id
      blob.signed_id
    end

    def variant(transformations)
      blob.variant(transformations_by_name(transformations))
    end

    def preview(transformations)
      blob.preview(transformations_by_name(transformations))
    end

    def representation(transformations)
      blob.representation(transformations_by_name(transformations))
    end

    def as_json(options = nil)
      { id: id, name: name, record_type: record_type, record_id: record_id, blob_id: blob_id }.as_json(options)
    end

    delegate_missing_to :blob

    private
      def analyze_option
        reflection&.options&.fetch(:analyze, nil)
      end

      def skip_later_analysis?
        (analyze_option || ActiveStorage.analyze) == :lazily
      end

      def run_upload_callbacks
        blob.mirror_later
        blob.analyze_later unless blob.analyzed? || skip_later_analysis?
      end

      def named_variants
        reflection&.named_variants || {}
      end

      def transformations_by_name(transformations)
        case transformations
        when Symbol
          variant_name = transformations
          named_variants.fetch(variant_name) do
            raise ArgumentError, "Cannot find variant :#{variant_name} for #{record_type}##{name}"
          end.transformations
        else
          transformations
        end
      end

      def reflection
        record_type.constantize.attachment_reflections[name]
      end

      def touch_record
        record.touch if record.respond_to?(:touch) && record.persisted?
      end
  end
end
