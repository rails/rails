# Abstract class serving as an interface for concrete services.
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
