# frozen_string_literal: true

require "active_support/core_ext/module/delegation"

module ActiveStorage
  # Wraps a set of mirror services and provides a single ActiveStorage::Service object that will all
  # have the files uploaded to them. A +primary+ service is designated to answer calls to:
  # * +download+
  # * +exists?+
  # * +url+
  # * +url_for_direct_upload+
  # * +headers_for_direct_upload+
  class Service::MirrorService < Service
    attr_reader :primary, :mirrors

    delegate :download, :download_chunk, :exist?, :url,
      :url_for_direct_upload, :headers_for_direct_upload, :path_for, :compose, to: :primary

    # Stitch together from named services.
    def self.build(primary:, mirrors:, name:, configurator:, **options) # :nodoc:
      new(
        primary: configurator.build(primary),
        mirrors: mirrors.collect { |mirror_name| configurator.build mirror_name }
      ).tap do |service_instance|
        service_instance.name = name
      end
    end

    def initialize(primary:, mirrors:)
      @primary, @mirrors = primary, mirrors
    end

    # Upload the +io+ to the +key+ specified to all services. If a +checksum+ is provided, all services will
    # ensure a match when the upload has completed or raise an ActiveStorage::IntegrityError.
    def upload(key, io, checksum: nil, **options)
      each_service.collect do |service|
        io.rewind
        service.upload key, io, checksum: checksum, **options
      end
    end

    # Delete the file at the +key+ on all services.
    def delete(key)
      perform_across_services :delete, key
    end

    # Delete files at keys starting with the +prefix+ on all services.
    def delete_prefixed(prefix)
      perform_across_services :delete_prefixed, prefix
    end


    # Copy the file at the +key+ from the primary service to each of the mirrors where it doesn't already exist.
    def mirror(key, checksum:)
      instrument :mirror, key: key, checksum: checksum do
        if (mirrors_in_need_of_mirroring = mirrors.select { |service| !service.exist?(key) }).any?
          primary.open(key, checksum: checksum) do |io|
            mirrors_in_need_of_mirroring.each do |service|
              io.rewind
              service.upload key, io, checksum: checksum
            end
          end
        end
      end
    end

    private
      def each_service(&block)
        [ primary, *mirrors ].each(&block)
      end

      def perform_across_services(method, *args)
        # FIXME: Convert to be threaded
        each_service.collect do |service|
          service.public_send method, *args
        end
      end
  end
end
