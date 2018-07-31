# frozen_string_literal: true

require "active_storage/log_subscriber"

module ActiveStorage
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
  # Inside a Rails application, you can set-up your services through the
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
  # If you are using Active Storage outside of a Ruby on Rails application, you
  # can configure the service to use like this:
  #
  #   ActiveStorage::Blob.service = ActiveStorage::Service.configure(
  #     :Disk,
  #     root: Pathname("/foo/bar/storage")
  #   )
  class Service
    extend ActiveSupport::Autoload
    autoload :Configurator

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
      def build(configurator:, service: nil, **service_config) #:nodoc:
        new(**service_config)
      end
    end

    # Upload the +io+ to the +key+ specified. If a +checksum+ is provided, the service will
    # ensure a match when the upload has completed or raise an ActiveStorage::IntegrityError.
    def upload(key, io, checksum: nil)
      raise NotImplementedError
    end

    # Return the content of the file at the +key+.
    def download(key)
      raise NotImplementedError
    end

    # Return the partial content in the byte +range+ of the file at the +key+.
    def download_chunk(key, range)
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

    # Returns a signed, temporary URL for the file at the +key+. The URL will be valid for the amount
    # of seconds specified in +expires_in+. You must also provide the +disposition+ (+:inline+ or +:attachment+),
    # +filename+, and +content_type+ that you wish the file to be served with on request.
    def url(key, expires_in:, disposition:, filename:, content_type:)
      raise NotImplementedError
    end

    # Returns a signed, temporary URL that a direct upload file can be PUT to on the +key+.
    # The URL will be valid for the amount of seconds specified in +expires_in+.
    # You must also provide the +content_type+, +content_length+, and +checksum+ of the file
    # that will be uploaded. All these attributes will be validated by the service upon upload.
    def url_for_direct_upload(key, expires_in:, content_type:, content_length:, checksum:)
      raise NotImplementedError
    end

    # Returns a Hash of headers for +url_for_direct_upload+ requests.
    def headers_for_direct_upload(key, filename:, content_type:, content_length:, checksum:)
      {}
    end

    private
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
        (type.to_s.presence_in(%w( attachment inline )) || "inline") + "; #{filename.parameters}"
      end
  end
end
