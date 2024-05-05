# frozen_string_literal: true

require "active_support/core_ext/module/delegation"

module ActiveStorage
  # = Active Storage Mirror \Service
  #
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
      @executor = Concurrent::ThreadPoolExecutor.new(
        min_threads: 1,
        max_threads: mirrors.size,
        max_queue: 0,
        fallback_policy: :caller_runs,
        idle_time: 60
      )
    end

    # Upload the +io+ to the +key+ specified to all services. The upload to the primary service is done synchronously
    # whereas the upload to the mirrors is done asynchronously. If a +checksum+ is provided, all services will
    # ensure a match when the upload has completed or raise an ActiveStorage::IntegrityError.
    def upload(key, io, checksum: nil, **options)
      io.rewind
      primary.upload key, io, checksum: checksum, **options
      mirror_later key, checksum: checksum
    end

    # Delete the file at the +key+ on all services.
    def delete(key)
      perform_across_services :delete, key
    end

    # Delete files at keys starting with the +prefix+ on all services.
    def delete_prefixed(prefix)
      perform_across_services :delete_prefixed, prefix
    end

    def mirror_later(key, checksum:) # :nodoc:
      ActiveStorage::MirrorJob.perform_later key, checksum: checksum
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
        tasks = each_service.collect do |service|
          Concurrent::Promise.execute(executor: @executor) do
            service.public_send method, *args
          end
        end
        tasks.each(&:value!)
      end
  end
end
