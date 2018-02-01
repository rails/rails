# frozen_string_literal: true

class ActiveStorage::Filename::Parameters #:nodoc:
  attr_reader :filename

  def initialize(filename)
    @filename = filename
  end

  def combined
    "#{ascii}; #{utf8}"
  end

  TRADITIONAL_ESCAPED_CHAR = /[^ A-Za-z0-9!#$+.^_`|~-]/

  def ascii
    'filename="' + percent_escape(I18n.transliterate(filename.sanitized), TRADITIONAL_ESCAPED_CHAR) + '"'
  end

  RFC_5987_ESCAPED_CHAR = /[^A-Za-z0-9!#$&+.^_`|~-]/

  def utf8
    "filename*=UTF-8''" + percent_escape(filename.sanitized, RFC_5987_ESCAPED_CHAR)
  end

  def to_s
    combined
  end

  private
    def percent_escape(string, pattern)
      string.gsub(pattern) do |char|
        char.bytes.map { |byte| "%%%02X" % byte }.join
      end
    end
end
