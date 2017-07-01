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

  def exists?(key)
    raise NotImplementedError
  end

  def url(key)
    raise NotImplementedError
  end

  def checksum(key)
    raise NotImplementedError
  end


  def copy(from_key:, to_key:)
    raise NotImplementedError
  end

  def move(from_key:, to_key:)
    raise NotImplementedError
  end
end

module ActiveFile::Sites
end
