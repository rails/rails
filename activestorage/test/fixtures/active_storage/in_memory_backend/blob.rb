# frozen_string_literal: true

module ActiveStorage::InMemoryBackend
  class Blob
    MINIMUM_TOKEN_LENGTH = 28

    include Store
    include ActiveStorage::Attached::Model
    include ActiveStorage::Servable

    attr_writer :filename, :key
    attr_accessor :content_type, :byte_size, :checksum, :metadata, :service_name, :local_io

    class << self
      def services
        ActiveStorage::Services.registry
      end

      def services=(registry)
        ActiveStorage::Services.registry = registry
      end

      def service
        ActiveStorage::Services.default
      end

      def service=(service)
        ActiveStorage::Services.default = service
      end

      def build_after_unfurling(key: nil, io:, filename:, content_type: nil, metadata: nil, service_name: nil, identify: true, record: nil)
        new(key: key, filename: filename, content_type: content_type, metadata: metadata, service_name: service_name).tap do |blob|
          blob.unfurl(io, identify: identify)
        end
      end

      def create_after_unfurling!(**options)
        build_after_unfurling(**options).tap(&:save!)
      end

      def create_and_upload!(io:, **options)
        create_after_unfurling!(io: io, **options).tap { |blob| blob.upload_without_unfurling(io) }
      end

      def create_before_direct_upload!(key: nil, filename:, byte_size:, checksum:, content_type: nil, metadata: nil, service_name: nil, record: nil)
        metadata = ActiveStorage.filter_blob_metadata(metadata)
        new(key: key, filename: filename, byte_size: byte_size, checksum: checksum, content_type: content_type, metadata: metadata, service_name: service_name).tap(&:save!)
      end

      def find_signed(id, record: nil, purpose: :blob_id)
        find_signed!(id, record: record, purpose: purpose)
      rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveStorage::RecordNotFound
        nil
      end

      def find_signed!(id, record: nil, purpose: :blob_id)
        find(ActiveStorage.verifier.verify(id, purpose: purpose.to_s))
      end

      def generate_unique_secure_token(length: MINIMUM_TOKEN_LENGTH)
        SecureRandom.base36(length)
      end

      def scope_for_strict_loading
        Relation.new(self)
      end
    end

    def initialize(attributes = {})
      super
      self.metadata ||= {}
      self.service_name ||= self.class.service&.name
    end

    def signed_id(purpose: :blob_id, expires_in: nil, expires_at: nil)
      ActiveStorage.verifier.generate(id, purpose: purpose.to_s, expires_in: expires_in, expires_at: expires_at)
    end

    def filename
      ActiveStorage::Filename.new(@filename)
    end

    def key
      @key ||= self.class.generate_unique_secure_token
    end

    def custom_metadata
      metadata[:custom] || metadata["custom"] || {}
    end

    def identified
      metadata[:identified] || metadata["identified"]
    end

    def identified=(value)
      metadata[:identified] = value
    end

    def analyzed
      metadata[:analyzed] || metadata["analyzed"]
    end

    def analyzed=(value)
      metadata[:analyzed] = value
    end

    def composed
      metadata[:composed] || metadata["composed"]
    end

    def composed=(value)
      metadata[:composed] = value
    end

    def identify_without_saving
      return if identified?

      self.content_type ||= "application/octet-stream"
      self.identified = true
    end

    def identified?
      identified
    end

    def analyze_without_saving
      self.metadata = metadata.merge(analyzed: true)
    end

    def analyze
      analyze_without_saving
      save!
    end

    def analyze_later
      ActiveStorage::AnalyzeJob.perform_later(self)
    end

    def analyzed?
      analyzed
    end

    def upload(io, identify: true)
      unfurl(io, identify: identify)
      upload_without_unfurling(io)
    end

    def unfurl(io, identify: true)
      self.checksum = service.compute_checksum(io)
      self.content_type = Marcel::MimeType.for(io, name: filename.to_s, declared_type: content_type) if content_type.nil? || identify
      self.byte_size = io.size
      self.identified = true
    end

    def upload_without_unfurling(io)
      service.upload(key, io, checksum: checksum, content_type: content_type)
    end

    def download(&block)
      service.download(key, &block)
    end

    def download_chunk(range)
      service.download_chunk(key, range)
    end

    def open(tmpdir: nil, &block)
      if local_io
        open_local_io(tmpdir: tmpdir, &block)
      else
        service.open(key, checksum: checksum, verify: !composed, name: [ "ActiveStorage-#{id}-", filename.extension_with_delimiter ], tmpdir: tmpdir, &block)
      end
    end

    def url(expires_in: ActiveStorage.service_urls_expire_in, disposition: :inline, filename: nil, **options)
      service.url(key, expires_in: expires_in, filename: ActiveStorage::Filename.wrap(filename || self.filename), content_type: content_type_for_serving, disposition: forced_disposition_for_serving || disposition, **options)
    end

    def service_url_for_direct_upload(expires_in: ActiveStorage.service_urls_expire_in)
      service.url_for_direct_upload(key, expires_in: expires_in, content_type: content_type, content_length: byte_size, checksum: checksum, custom_metadata: custom_metadata)
    end

    def service_headers_for_direct_upload
      service.headers_for_direct_upload(key, filename: filename, content_type: content_type, content_length: byte_size, checksum: checksum, custom_metadata: custom_metadata)
    end

    def image?
      content_type&.start_with?("image")
    end

    def audio?
      content_type&.start_with?("audio")
    end

    def video?
      content_type&.start_with?("video")
    end

    def text?
      content_type&.start_with?("text")
    end

    def variable?
      ActiveStorage.variable_content_types.include?(content_type)
    end

    def previewable?
      ActiveStorage.previewers.any? { |klass| klass.accept?(self) }
    end

    def representable?
      variable? || previewable?
    end

    def variant(transformations)
      if variable?
        variant_class.new(self, ActiveStorage::Variation.wrap(transformations).default_to(default_variant_transformations))
      else
        raise ActiveStorage::InvariableError, "Can't transform blob with ID=#{id} and content_type=#{content_type}"
      end
    end

    def preview(transformations)
      if previewable?
        ActiveStorage::Preview.new(self, transformations)
      else
        raise ActiveStorage::UnpreviewableError, "No previewer found for blob with ID=#{id} and content_type=#{content_type}"
      end
    end

    def representation(transformations)
      case
      when previewable?
        preview(transformations)
      when variable?
        variant(transformations)
      else
        raise ActiveStorage::UnrepresentableError, "No previewer found and can't transform blob with ID=#{id} and content_type=#{content_type}"
      end
    end

    def attachments
      ActiveStorage.attachment_class.where(blob_id: id)
    end

    def service
      self.class.services.fetch(service_name)
    end

    def mirror_later
      service.mirror_later(key, checksum: checksum) if service.respond_to?(:mirror_later)
    end

    def delete
      service.delete(key)
      service.delete_prefixed("variants/#{key}/") if image?
    end

    def destroy
      raise ActiveStorage::ForeignKeyViolation if attachments.any?

      variant_records.destroy_all if ActiveStorage.track_variants

      super
    end

    def purge
      destroy
      delete if previously_persisted?
    rescue ActiveStorage::ForeignKeyViolation
    end

    def purge_later
      ActiveStorage::PurgeJob.perform_later(self)
    end

    private
      def open_local_io(tmpdir:)
        Tempfile.open([ "ActiveStorage-#{id}-", filename.extension_with_delimiter ], tmpdir) do |file|
          file.binmode
          local_io.rewind if local_io.respond_to?(:rewind)
          IO.copy_stream(local_io, file)
          local_io.rewind if local_io.respond_to?(:rewind)
          file.rewind
          yield file
        end
      end

      def default_variant_transformations
        { format: default_variant_format }
      end

      def default_variant_format
        if ActiveStorage.web_image_content_types.include?(content_type)
          filename.extension.presence || :png
        else
          :png
        end
      end

      def variant_records
        ActiveStorage.variant_record_class.where(blob_id: id)
      end

      def variant_class
        ActiveStorage.track_variants ? ActiveStorage::VariantWithRecord : ActiveStorage::Variant
      end
  end
end
