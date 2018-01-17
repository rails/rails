# frozen_string_literal: true

# Encapsulates a string representing a filename to provide convenient access to parts of it and sanitization.
# A Filename instance is returned by ActiveStorage::Blob#filename, and is comparable so it can be used for sorting.
class ActiveStorage::Filename
  include Comparable

  def initialize(filename)
    @filename = filename
  end

  # Returns the part of the filename preceding any extension.
  #
  #   ActiveStorage::Filename.new("racecar.jpg").base # => "racecar"
  #   ActiveStorage::Filename.new("racecar").base     # => "racecar"
  #   ActiveStorage::Filename.new(".gitignore").base  # => ".gitignore"
  def base
    File.basename @filename, extension_with_delimiter
  end

  # Returns the extension of the filename (i.e. the substring following the last dot, excluding a dot at the
  # beginning) with the dot that precedes it. If the filename has no extension, an empty string is returned.
  #
  #   ActiveStorage::Filename.new("racecar.jpg").extension_with_delimiter # => ".jpg"
  #   ActiveStorage::Filename.new("racecar").extension_with_delimiter     # => ""
  #   ActiveStorage::Filename.new(".gitignore").extension_with_delimiter  # => ""
  def extension_with_delimiter
    File.extname @filename
  end

  # Returns the extension of the filename (i.e. the substring following the last dot, excluding a dot at
  # the beginning). If the filename has no extension, an empty string is returned.
  #
  #   ActiveStorage::Filename.new("racecar.jpg").extension_without_delimiter # => "jpg"
  #   ActiveStorage::Filename.new("racecar").extension_without_delimiter     # => ""
  #   ActiveStorage::Filename.new(".gitignore").extension_without_delimiter  # => ""
  def extension_without_delimiter
    extension_with_delimiter.from(1).to_s
  end

  alias_method :extension, :extension_without_delimiter

  # Returns the sanitized filename.
  #
  #   ActiveStorage::Filename.new("foo:bar.jpg").sanitized # => "foo-bar.jpg"
  #   ActiveStorage::Filename.new("foo/bar.jpg").sanitized # => "foo-bar.jpg"
  #
  # Characters considered unsafe for storage (e.g. \, $, and the RTL override character) are replaced with a dash.
  def sanitized
    @filename.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "�").strip.tr("\u{202E}%$|:;/\t\r\n\\", "-")
  end

  def parameters #:nodoc:
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
