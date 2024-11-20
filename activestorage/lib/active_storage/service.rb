# frozen_string_literal: true

require "active_storage/log_subscriber"
require "active_storage/downloader"
require "action_dispatch"
require "action_dispatch/http/content_disposition"

module ActiveStorage
  # = Active Storage \Service
  #
  # Abstract class serving as an interface for concrete services.
  #
  # The available services are:
  #
  # * +Disk+, to manage attachments saved directly on the hard drive.
  # * +GCS+, to manage attachments through Google Cloud Storage.
  # * +S3+, to manage attachments through Amazon S3.
  # * +AzureStorage+, to manage attachments through Microsoft Azure Storage.
  # * +Mirror+, to be able to use several services to manage attachments.
  #
  # Inside a \Rails application, you can set-up your services through the
  # generated <tt>config/storage.yml</tt> file and reference one
  # of the aforementioned constant under the +service+ key. For example:
  #
  #   local:
  #     service: Disk
  #     root: <%= Rails.root.join("storage") %>
  #
  # You can checkout the service's constructor to know which keys are required.
  #
  # Then, in your application's configuration, you can specify the service to
  # use like this:
  #
  #   config.active_storage.service = :local
  #
  # If you are using Active Storage outside of a Ruby on \Rails application, you
  # can configure the service to use like this:
  #
  #   ActiveStorage::Blob.service = ActiveStorage::Service.configure(
  #     :local,
  #     { local: {service: "Disk",  root: Pathname("/tmp/foo/storage") } }
  #   )
  class Service
    extend ActiveSupport::Autoload
    autoload :Configurator
    attr_accessor :name

    class << self
      # Configure an Active Storage service by name from a set of configurations,
      # typically loaded from a YAML file. The Active Storage engine uses this
      # to set the global Active Storage service when the app boots.
      def configure(service_name, configurations)
        Configurator.build(service_name, configurations)
      end

      # Override in subclasses that stitch together multiple services and hence
      # need to build additional services using the configurator.
      #
      # Passes the configurator and all of the service's config as keyword args.
      #
      # See MirrorService for an example.
      def build(configurator:, name:, service: nil, **service_config) # :nodoc:
        new(**service_config).tap do |service_instance|
          service_instance.name = name
        end
      end
    end

    # Upload the +io+ to the +key+ specified. If a +checksum+ is provided, the service will
    # ensure a match when the upload has completed or raise an ActiveStorage::IntegrityError.
    def upload(key, io, checksum: nil, **options)
      raise NotImplementedError
    end

    # Update metadata for the file identified by +key+ in the service.
    # Override in subclasses only if the service needs to store specific
    # metadata that has to be updated upon identification.
    def update_metadata(key, **metadata)
    end

    # Return the content of the file at the +key+.
    def download(key)
      raise NotImplementedError
    end

    # Return the partial content in the byte +range+ of the file at the +key+.
    def download_chunk(key, range)
      raise NotImplementedError
    end

    def open(*args, **options, &block)
      ActiveStorage::Downloader.new(self).open(*args, **options, &block)
    end

    # Concatenate multiple files into a single "composed" file.
    def compose(source_keys, destination_key, filename: nil, content_type: nil, disposition: nil, custom_metadata: {})
      raise NotImplementedError
    end

    # Delete the file at the +key+.
    def delete(key)
      raise NotImplementedError
    end

    # Delete files at keys starting with the +prefix+.
    def delete_prefixed(prefix)
      raise NotImplementedError
    end

    # Return +true+ if a file exists at the +key+.
    def exist?(key)
      raise NotImplementedError
    end

    # Returns the URL for the file at the +key+. This returns a permanent URL for public files, and returns a
    # short-lived URL for private files. For private files you can provide the +disposition+ (+:inline+ or +:attachment+),
    # +filename+, and +content_type+ that you wish the file to be served with on request. Additionally, you can also provide
    # the amount of seconds the URL will be valid for, specified in +expires_in+.
    def url(key, **options)
      instrument :url, key: key do |payload|
        generated_url =
          if public?
            public_url(key, **options)
          else
            private_url(key, **options)
          end

        payload[:url] = generated_url

        generated_url
      end
    end

    # Returns a signed, temporary URL that a direct upload file can be PUT to on the +key+.
    # The URL will be valid for the amount of seconds specified in +expires_in+.
    # You must also provide the +content_type+, +content_length+, and +checksum+ of the file
    # that will be uploaded. All these attributes will be validated by the service upon upload.
    def url_for_direct_upload(key, expires_in:, content_type:, content_length:, checksum:, custom_metadata: {})
      raise NotImplementedError
    end

    # Returns a Hash of headers for +url_for_direct_upload+ requests.
    def headers_for_direct_upload(key, filename:, content_type:, content_length:, checksum:, custom_metadata: {})
      {}
    end

    def public?
      @public
    end

    private
      def private_url(key, expires_in:, filename:, disposition:, content_type:, **)
        raise NotImplementedError
      end

      def public_url(key, **)
        raise NotImplementedError
      end

      def custom_metadata_headers(metadata)
        raise NotImplementedError
      end

      def instrument(operation, payload = {}, &block)
        ActiveSupport::Notifications.instrument(
          "service_#{operation}.active_storage",
          payload.merge(service: service_name), &block)
      end

      def service_name
        # ActiveStorage::Service::DiskService => Disk
        self.class.name.split("::").third.remove("Service")
      end

      def content_disposition_with(type: "inline", filename:)
        disposition = (type.to_s.presence_in(%w( attachment inline )) || "inline")
        ActionDispatch::Http::ContentDisposition.format(disposition: disposition, filename: filename.sanitized)
      end
  end
end
