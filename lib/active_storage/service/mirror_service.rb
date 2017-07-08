require "active_support/core_ext/module/delegation"

class ActiveStorage::Service::MirrorService < ActiveStorage::Service
  attr_reader :primary, :mirrors

  delegate :download, :exist?, :url, to: :primary

  # Stitch together from named configuration.
  def self.build(mirror_config, all_configurations) #:nodoc:
    primary = ActiveStorage::Service.configure(mirror_config.fetch(:primary), all_configurations)

    mirrors = mirror_config.fetch(:mirrors).collect do |service_name|
      ActiveStorage::Service.configure(service_name.to_sym, all_configurations)
    end

    new primary: primary, mirrors: mirrors
  end

  def initialize(primary:, mirrors:)
    @primary, @mirrors = primary, mirrors
  end

  def upload(key, io, checksum: nil)
    each_service.collect do |service|
      service.upload key, io.tap(&:rewind), checksum: checksum
    end
  end

  def delete(key)
    perform_across_services :delete, key
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
