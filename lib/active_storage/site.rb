# Abstract class serving as an interface for concrete sites.
class ActiveStorage::Site
  def self.configure(site, **options)
    begin
      require "active_storage/site/#{site.to_s.downcase}_site"
      ActiveStorage::Site.const_get(:"#{site}Site").new(**options)
    rescue LoadError => e
      puts "Couldn't configure site: #{site} (#{e.message})"
    end
  end


  def upload(key, io)
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

  def bytesize(key)
    raise NotImplementedError
  end

  def checksum(key)
    raise NotImplementedError
  end
end
