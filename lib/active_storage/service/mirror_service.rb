class ActiveStorage::Service::MirrorService < ActiveStorage::Service
  attr_reader :services

  def initialize(services:)
    @services = services
  end

  def upload(key, io)
    services.collect do |service|
      service.upload key, io
      io.rewind
    end
  end

  def download(key)
    services.detect { |service| service.exist?(key) }.download(key)
  end

  def delete(key)
    perform_across_services :delete, key
  end

  def exist?(key)
    perform_across_services(:exist?, key).any?
  end


  def url(key, **options)
    primary_service.url(key, **options)
  end

  def byte_size(key)
    primary_service.byte_size(key)
  end

  def checksum(key)
    primary_service.checksum(key)
  end

  private
    def primary_service
      services.first
    end

    def perform_across_services(method, *args)
      # FIXME: Convert to be threaded
      services.collect do |service|
        service.public_send method, *args
      end
    end
end
