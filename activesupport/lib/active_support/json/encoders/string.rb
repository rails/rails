module ActiveSupport
  module JSON
    module Encoding
      mattr_accessor :escape_regex

      ESCAPED_CHARS = {
        "\010" =>  '\b',
        "\f"   =>  '\f',
        "\n"   =>  '\n',
        "\r"   =>  '\r',
        "\t"   =>  '\t',
        '"'    =>  '\"',
        '\\'   =>  '\\\\',
        '>'    =>  '\u003E',
        '<'    =>  '\u003C',
        '&'    =>  '\u0026'
      }
    end
  end
end

ActiveSupport.escape_html_entities_in_json = true

class String
  def to_json(options = nil) #:nodoc:
    json = '"' + gsub(ActiveSupport::JSON::Encoding.escape_regex) { |s|
      ActiveSupport::JSON::Encoding::ESCAPED_CHARS[s]
    }
    json.force_encoding('ascii-8bit') if respond_to?(:force_encoding)
    json.gsub(/([\xC0-\xDF][\x80-\xBF]|
             [\xE0-\xEF][\x80-\xBF]{2}|
             [\xF0-\xF7][\x80-\xBF]{3})+/nx) { |s|
      s.unpack("U*").pack("n*").unpack("H*")[0].gsub(/.{4}/, '\\\\u\&')
    } + '"'
  end
end
