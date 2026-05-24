# frozen_string_literal: true

# :markup: markdown

require "active_support/core_ext/hash/indifferent_access"

module ActiveStorage::Attached::GenericLifecycle # :nodoc:
  SUCCESSFUL = ActiveSupport::Callbacks::Conditionals::Value.new { |value| value != false }

  def self.install(model)
    return if model < self

    model.include self
    model.singleton_class.prepend CallbackDefinitions
    model.set_callback :validation, :before, :analyze_attachment_changes
    model.set_callback :save, :after, :save_attachment_changes, prepend: true, if: SUCCESSFUL
    model.set_callback :destroy, :before, :capture_attachment_owner, prepend: true
    model.set_callback :destroy, :after, :destroy_owner_attachments, prepend: true, if: SUCCESSFUL
    [model, *model.descendants].each { |owner| install_transaction_callbacks(owner) }
  end

  def self.install_transaction_callbacks(model, names = [:commit, :rollback])
    if names.include?(:commit) && model.respond_to?(:_commit_callbacks, true)
      model.set_callback :commit, :after, :commit_attachment_changes, prepend: true, if: SUCCESSFUL
    end
    if names.include?(:rollback) && model.respond_to?(:_rollback_callbacks, true)
      model.set_callback :rollback, :after, :rollback_attachment_changes, prepend: true
    end
  end

  module CallbackDefinitions
    def define_callbacks(*names)
      super.tap do
        chains = names.grep(Symbol).concat(names.grep(String).map(&:to_sym))
        ActiveStorage::Attached::GenericLifecycle.install_transaction_callbacks(self, chains)
      end
    end
  end

  class State
    Upload = Struct.new(:source, :metadata)
    SavedChange = Struct.new(:name, :change, :attachments)
    SavedAttachment = Struct.new(:record_type, :record_id, :name, :id, :blob_id)

    def initialize
      @uploads = []
      @saved_changes = []
      @purges = []
      @destroyed_changes = {}
    end

    def assigned(record, change)
      @destroyed_changes.delete(change.name)
      if change.respond_to?(:upload_sources)
        change.upload_sources.each do |source|
          unless source.uploaded? || upload_for(source.blob)
            @uploads << Upload.new(source, source.blob.metadata.deep_dup).freeze
          end
        end
      end
      prune(record)
      change
    end

    def saved(name, change)
      attachments = attachments_for(change).map do |attachment|
        SavedAttachment.new(attachment.record_type.dup.freeze, attachment.record_id.dup.freeze,
          attachment.name.dup.freeze, attachment.id.dup.freeze, attachment.blob_id.dup.freeze).freeze
      end
      @saved_changes.reject! { |saved| saved.change.equal?(change) }
      @saved_changes << SavedChange.new(name, change, attachments.freeze).freeze
      @purges.concat(change.deferred_purges)
      change.reset_deferred_purges
    end

    def destroyed(record, purges)
      @destroyed_changes.merge!(record.attachment_changes)
      @purges.concat(purges)
    end

    def upload_source_for(blob)
      source = upload_for(blob)&.source
      source unless source&.uploaded?
    end

    def prune(record)
      blobs = pending_blobs(record)
      saved_blob_ids = @saved_changes.flat_map(&:attachments).map(&:blob_id)
      @uploads.reject! do |upload|
        blob = upload.source.blob
        upload.source.uploaded? || !(blobs.any? { |selected| same_blob?(blob, selected) } || (blob.id && saved_blob_ids.include?(blob.id)))
      end
    end

    def rollback(record)
      record.attachment_changes.replace(@destroyed_changes.merge(record.attachment_changes))
      @saved_changes.clear
      @purges.clear
      @destroyed_changes.clear
      prune(record)
    end

    def reloaded(record)
      @destroyed_changes.clear
      prune(record)
    end

    def reconcile_metadata(record, blob)
      if upload = upload_for(blob)
        before, after = upload.metadata.with_indifferent_access, blob.metadata.with_indifferent_access
        return if before == after

        aliases = pending_blobs(record) + record.send(:cached_attachment_blobs, blob) + [upload.source.blob]
        aliases.each do |other|
          if !other.equal?(blob) && same_blob?(blob, other)
            other.metadata = merge_metadata(before, after, other.metadata.with_indifferent_access)
          end
        end
      end
    end

    def commit(record)
      # Upload callbacks can save again. Finish this upload before draining their commit.
      if @committing
        @commit_requested = true
        return
      end

      @committing = true
      begin
        loop do
          @commit_requested = false
          saved_changes, purges, destroyed_changes = @saved_changes.dup, @purges.dup, @destroyed_changes.dup
          upload(record, saved_changes) if record.persisted?

          saved_changes.group_by(&:name).each do |name, changes|
            latest = @saved_changes.reverse.find { |saved| saved.name == name }
            if latest.equal?(changes.last) && record.attachment_changes[name].equal?(latest.change)
              record.attachment_changes.delete(name)
            end
          end
          @saved_changes.reject! { |saved| saved_changes.any? { |captured| captured.equal?(saved) } }

          ActiveStorage::Attached::Changes.flush_pending_purges(purges)
          @purges.reject! { |purge| purges.any? { |captured| captured.equal?(purge) } }
          @destroyed_changes.reject! { |name, change| destroyed_changes[name].equal?(change) }
          prune(record)
          break unless @commit_requested
        end
      ensure
        @committing = false
      end
    end

    private
      def upload(record, saved_changes)
        targets = saved_changes.flat_map(&:attachments)
        @uploads.dup.each do |upload|
          if attachment = upload_attachment(upload.source.blob, targets)
            upload.source.upload(attachment: attachment)
            reconcile_metadata(record, attachment.blob)
          end
        end

        record.attachment_changes.each_value do |change|
          if change.respond_to?(:pending_uploads)
            change.pending_uploads.reject!(&:uploaded?)
          end
        end
      end

      def upload_attachment(blob, targets)
        targets.reverse_each do |target|
          next unless target.blob_id == blob.id

          attachments = ActiveStorage.attachment_class.where(record_type: target.record_type,
            record_id: target.record_id, name: target.name, blob_id: target.blob_id).to_a
          if attachments.any?
            return attachments.find { |attachment| attachment.id == target.id } || attachments.first
          end
        end
        nil
      end

      def upload_for(blob)
        @uploads.find { |upload| same_blob?(upload.source.blob, blob) }
      end

      def same_blob?(first, second)
        first.equal?(second) || first == second
      end

      def pending_blobs(record)
        (@destroyed_changes.values + record.attachment_changes.values).flat_map do |change|
          if change.respond_to?(:blobs)
            change.blobs
          elsif change.respond_to?(:blob)
            [change.blob]
          else
            []
          end
        end
      end

      def merge_metadata(before, after, current)
        # Preserve metadata edited on a pending blob while copying analysis and persisted changes.
        current.deep_dup.tap do |merged|
          (before.keys | after.keys).each do |key|
            next if before.key?(key) == after.key?(key) && before[key] == after[key]

            if after[key].is_a?(Hash) && current[key].is_a?(Hash) && (before[key].is_a?(Hash) || !before.key?(key))
              merged[key] = merge_metadata(before[key] || {}, after[key], current[key])
            elsif current.key?(key) == before.key?(key) && current[key] == before[key]
              after.key?(key) ? merged[key] = after[key].deep_dup : merged.delete(key)
            end
          end
        end
      end

      def attachments_for(change)
        change.respond_to?(:attachments) ? change.attachments : Array(change.attachment)
      end
  end

  def initialize_dup(*)
    super
    clear_active_storage_attachment_memoizations
    @active_storage_lifecycle = nil
    @active_storage_destroying = nil
  end

  def reload(*)
    result = defined?(super) ? super : self
    clear_active_storage_attachment_memoizations
    @active_storage_lifecycle&.reloaded(self)
    result
  end

  private
    def cached_attachment_blobs(blob)
      self.class.attachment_reflections.keys.flat_map do |name|
        blobs = Array(instance_variable_get(:"@#{name}_blob"))
        attachments = Array(instance_variable_get(:"@#{name}_attachment"))

        many_blobs = instance_variable_get(:"@#{name}_blobs")
        blobs.concat(many_blobs.is_a?(ActiveStorage::Attached::BlobsCollection) ? many_blobs.cached : Array(many_blobs))
        many_attachments = instance_variable_get(:"@#{name}_attachments")
        attachments.concat(many_attachments.is_a?(ActiveStorage::Attached::Collection) ? many_attachments.cached : Array(many_attachments))

        blobs.concat(attachments.filter_map { |attachment| attachment.blob if attachment.blob_id == blob.id })
      end
    end

    def clear_active_storage_attachment_memoizations
      remove_instance_variable(:@active_storage_attached) if instance_variable_defined?(:@active_storage_attached)
      remove_instance_variable(:@attachment_changes) if instance_variable_defined?(:@attachment_changes)

      self.class.attachment_reflections.each_key do |name|
        %w[attachment blob attachments blobs].each do |suffix|
          ivar = :"@#{name}_#{suffix}"
          remove_instance_variable(ivar) if instance_variable_defined?(ivar)
        end
      end
    end

    def analyze_attachment_changes
      attachment_changes.each_value(&:analyze)
    end

    def save_attachment_changes
      changes = attachment_changes.to_a
      unless changes.empty?
        if id.nil?
          raise ActiveStorage::OwnerContractMissing, "#{self.class.name} must assign an id before saving attachments."
        end
        unless persisted?
          raise ActiveStorage::OwnerContractMissing, "#{self.class.name} must be persisted during after_save callbacks before saving attachments."
        end

        begin
          ActiveStorage.attachment_class.transaction do
            mark_pending_uploads(changes)
            changes.each { |_name, change| change.save }
          end
        rescue StandardError
          changes.each { |_name, change| change.reset_deferred_purges }
          raise
        end

        changes.each { |name, change| attachment_lifecycle.saved(name, change) }
      end
      commit_attachment_changes unless self.class.respond_to?(:_commit_callbacks, true)
    end

    def mark_pending_uploads(changes)
      changes.each do |_name, change|
        attachments = change.respond_to?(:attachments) ? change.attachments : Array(change.attachment)
        attachments.each do |attachment|
          attachment.pending_upload = attachment_lifecycle.upload_source_for(attachment.blob).present?
        end
      end
    end

    def attachment_upload_source(blob)
      @active_storage_lifecycle&.upload_source_for(blob)
    end

    def reconcile_attachment_metadata(blob)
      @active_storage_lifecycle&.reconcile_metadata(self, blob)
    end

    def prune_attachment_uploads
      @active_storage_lifecycle&.prune(self)
    end

    def capture_attachment_owner
      @active_storage_destroying = [ActiveStorage::Attached::Changes.polymorphic_name(self), id, persisted?]
    end

    def destroy_owner_attachments
      record_type, record_id, was_persisted = @active_storage_destroying
      return unless was_persisted && !persisted?

      purges = self.class.attachment_reflections.keys.flat_map do |name|
        ActiveStorage.attachment_class.where(record_type: record_type, record_id: record_id, name: name).filter_map do |attachment|
          ActiveStorage::Attached::Changes.destroy_attachment(self, name, attachment)
        end
      end
      attachment_lifecycle.destroyed(self, purges)
      clear_active_storage_attachment_memoizations
      commit_attachment_changes unless self.class.respond_to?(:_commit_callbacks, true)
    end

    def commit_attachment_changes
      @active_storage_lifecycle&.commit(self)
    end

    def rollback_attachment_changes
      changes = @attachment_changes
      clear_active_storage_attachment_memoizations
      @attachment_changes = changes if changes
      @active_storage_lifecycle&.rollback(self)
    end

    def attachment_lifecycle
      @active_storage_lifecycle ||= State.new
    end
end
