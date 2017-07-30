# Encapsulates a string representing a filename to provide convenience access to parts of it and a sanitized version.
# This is what's returned by `ActiveStorage::Blob#filename`. A Filename instance is comparable so it can be used for sorting.
class ActiveStorage::Filename
  include Comparable

  def initialize(filename)
    @filename = filename
  end

  # Filename.new("racecar.jpg").extname # => ".jpg"
  def extname
    File.extname(@filename)
  end

  # Filename.new("racecar.jpg").extension # => "jpg"
  def extension
    extname.from(1)
  end

  # Filename.new("racecar.jpg").base # => "racecar"
  def base
    File.basename(@filename, extname)
  end

  # Filename.new("foo:bar.jpg").sanitized # => "foo-bar.jpg"
  # Filename.new("foo/bar.jpg").sanitized # => "foo-bar.jpg"
  #
  # ...and any other character unsafe for URLs or storage is converted or stripped.
  def sanitized
    @filename.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "�").strip.tr("\u{202E}%$|:;/\t\r\n\\", "-")
  end

  # Returns the sanitized version of the filename.
  def to_s
    sanitized.to_s
  end

  def as_json(*)
    to_s
  end

  def to_json
    to_s
  end

  def <=>(other)
    to_s.downcase <=> other.to_s.downcase
  end
end
