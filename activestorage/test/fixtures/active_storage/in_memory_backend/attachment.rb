# frozen_string_literal: true

module ActiveStorage::InMemoryBackend
  class Attachment
    include Store

    attr_accessor :record_type, :record_id, :name, :blob_id, :pending_upload, :immediate_variants_processed
    self.storage_attributes += %i[record_type record_id name blob_id]

    after_commit :run_upload_callbacks, if: -> { @upload_callbacks_pending && persisted? }
    after_rollback { @upload_callbacks_pending = false }

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
      self.record_id ||= record&.id
      self.blob_id ||= blob&.id
      @upload_callbacks_pending ||= new_record? && !pending_upload
      super
    end

    def uploaded(io:)
      blob.local_io = io
      blob.analyze_without_saving unless blob.analyzed? || skip_later_analysis?
      io.rewind if io.respond_to?(:rewind)
      blob.upload_without_unfurling(io)
      blob.save! if blob.persisted?
      run_upload_callbacks
    ensure
      blob.local_io = nil
    end

    def reload
      @record = @blob = nil
      super
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
        @upload_callbacks_pending = false
        blob.mirror_later
        blob.analyze_later unless blob.analyzed? || skip_later_analysis?
        create_variants
      end

      def create_variants
        return unless blob.representable?

        immediate_variants = []
        later_variants = []
        named_variants.each_value do |variant|
          case variant.process(record)
          when :immediately
            immediate_variants << variant.transformations unless immediate_variants_processed
          when :later
            later_variants << variant.transformations
          end
        end

        ActiveStorage::CreateVariantsJob.perform_now(blob, variants: immediate_variants, process: :immediately) if immediate_variants.any?
        ActiveStorage::CreateVariantsJob.perform_later(blob, variants: later_variants, process: :later) if later_variants.any?
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
