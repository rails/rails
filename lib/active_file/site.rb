# Abstract class serving as an interface for concrete sites.
class ActiveFile::Site
  def initialize
  end

  def upload(key, data)
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

  def url(key)
    raise NotImplementedError
  end

  def checksum(key)
    raise NotImplementedError
  end


  def copy(from:, to:)
    raise NotImplementedError
  end

  def move(from:, to:)
    raise NotImplementedError
  end
end

module ActiveFile::Sites
end

require "active_file/sites/disk_site"
