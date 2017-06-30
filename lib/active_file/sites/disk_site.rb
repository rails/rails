class ActiveFile::Sites::DiskSite < ActiveFile::Site
  attr_reader :root

  def initialize(root)
    @root = root
  end

  def upload(key, data)
    File.open(make_path_for(key), "wb") do |file|
      while chunk = data.read(65536)
        file.write(chunk)
      end
    end
  end

  def download(key)
    if block_given?
      open(key) do |file|
        while data = file.read(65536)
          yield data
        end
      end
    else
      open(key, &:read)
    end
  end

  def delete(key)
    File.delete(path_for(key))
    true
  end

  def size(key)
    File.size(path_for(key))
  end

  def checksum(key)
    Digest::MD5.file(path_for(key)).hexdigest
  end

  private
    def path_for(key)
      File.join(root, folder_for(key), normalize(key))
    end

    def folder_for(key)
      [key[0..1], key[2..3]].join("/")
    end

    def make_path_for(key)
      path_for(key).tap { |path| FileUtils.mkdir_p File.dirname(path) }
    end
end
