class ActiveFile::Site
  def initialize
  end

  def upload(key, data)
  end

  def download(key)
  end

  def delete(key)
  end

  def exists?(key)
  end

  def url(key)
  end

  def checksum(key)
  end


  def copy(from_key:, to_key:)
  end

  def move(from_key:, to_key:)
  end


  private
    def normalize_key(key)
      # disallow "." and ".." segments in the key
      key.split(%r[/]).reject { |s| s == "." || s == ".." }
    end
end
