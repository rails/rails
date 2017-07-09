require_relative "log_subscriber"

# Abstract class serving as an interface for concrete services.
#
# The available services are:
#
# * +Disk+, to manage attachments saved directly on the hard drive.
# * +GCS+, to manage attachments through Google Cloud Storage.
# * +S3+, to manage attachments through Amazon S3.
# * +Mirror+, to be able to use several services to manage attachments.
#
# Inside a Rails application, you can set-up your services through the
# generated <tt>config/storage_services.yml</tt> file and reference one
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
class ActiveStorage::Service
  class ActiveStorage::IntegrityError < StandardError; end

  extend ActiveSupport::Autoload
  autoload :Configurator

  class_attribute :logger

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

  def upload(key, io, checksum: nil)
    raise NotImplementedError
  end

  def download(key)
    raise NotImplementedError
  end

  def delete(key)
    raise NotImplementedError
  end

  def exist?(key)
    raise NotImplementedError
  end

  def url(key, expires_in:, disposition:, filename:)
    raise NotImplementedError
  end

  def url_for_direct_upload(key, expires_in:, content_type:, content_length:)
    raise NotImplementedError
  end

  private
    def instrument(operation, key, payload = {}, &block)
      ActiveSupport::Notifications.instrument(
        "service_#{operation}.active_storage", 
        payload.merge(key: key, service: service_name), &block)
    end

    def service_name
      # ActiveStorage::Service::DiskService => Disk
      self.class.name.split("::").third.remove("Service")
    end
end
