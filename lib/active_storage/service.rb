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

  def self.configure(service, **options)
    begin
      require "active_storage/service/#{service.to_s.downcase}_service"
      ActiveStorage::Service.const_get(:"#{service}Service").new(**options)
    rescue LoadError => e
      puts "Couldn't configure service: #{service} (#{e.message})"
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
end
