# frozen_string_literal: true

# Encapsulates a string representing a filename to provide convenience access to parts of it and a sanitized version.
# This is what's returned by ActiveStorage::Blob#filename. A Filename instance is comparable so it can be used for sorting.
class ActiveStorage::Filename
  include Comparable

  def initialize(filename)
    @filename = filename
  end

  # Returns the basename of the filename.
  #
  #   ActiveStorage::Filename.new("racecar.jpg").base # => "racecar"
  def base
    File.basename @filename, extension_with_delimiter
  end

  # Returns the extension with delimiter of the filename.
  #
  #   ActiveStorage::Filename.new("racecar.jpg").extension_with_delimiter # => ".jpg"
  def extension_with_delimiter
    File.extname @filename
  end

  # Returns the extension without delimiter of the filename.
  #
  #   ActiveStorage::Filename.new("racecar.jpg").extension_without_delimiter # => "jpg"
  def extension_without_delimiter
    extension_with_delimiter.from(1).to_s
  end

  alias_method :extension, :extension_without_delimiter

  # Returns the sanitized filename.
  #
  #   ActiveStorage::Filename.new("foo:bar.jpg").sanitized # => "foo-bar.jpg"
  #   ActiveStorage::Filename.new("foo/bar.jpg").sanitized # => "foo-bar.jpg"
  #
  # ...and any other character unsafe for URLs or storage is converted or stripped.
  def sanitized
    @filename.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "�").strip.tr("\u{202E}%$|:;/\t\r\n\\", "-")
  end

  def parameters
    Parameters.new self
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
