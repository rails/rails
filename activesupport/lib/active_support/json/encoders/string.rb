module ActiveSupport
  module JSON
    module Encoding
      ESCAPED_CHARS = {
        "\010" =>  '\b',
        "\f" =>    '\f',
        "\n" =>    '\n',
        "\r" =>    '\r',
        "\t" =>    '\t',
        '"' =>     '\"',
        '\\' =>    '\\\\',
        ">" =>     '\076',
        '<' =>     '\074'
      }
    end
  end
end

class String
  def to_json #:nodoc:
    '"' + gsub(/[\010\f\n\r\t"\\><]/) { |s|
      ActiveSupport::JSON::Encoding::ESCAPED_CHARS[s]
    }.gsub(/([\xC0-\xDF][\x80-\xBF]|
             [\xE0-\xEF][\x80-\xBF]{2}|
             [\xF0-\xF7][\x80-\xBF]{3})+/nx) { |s|
      s.unpack("U*").pack("n*").unpack("H*")[0].gsub(/.{4}/, '\\\\u\&')
    } + '"'
  end
end
