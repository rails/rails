class ActiveStorage::Filename
  include Comparable

  def initialize(filename)
    @filename = filename
  end

  def extname
    File.extname(@filename)
  end

  def extension
    extname.from(1)
  end

  def base
    File.basename(@filename, extname)
  end

  def sanitized
    @filename.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "�").strip.tr("\u{202E}%$|:;/\t\r\n\\", "-")
  end

  def to_s
    sanitized.to_s
  end

  def <=>(other)
    to_s.downcase <=> other.to_s.downcase
  end
end
