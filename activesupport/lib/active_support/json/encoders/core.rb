module ActiveSupport
  module JSON #:nodoc:
    module Encoders #:nodoc:
      define_encoder Object do |object|
        object.instance_values.to_json
      end
      
      define_encoder TrueClass do
        'true'
      end
      
      define_encoder FalseClass do
        'false'
      end
      
      define_encoder NilClass do
        'null'
      end

      ESCAPED_CHARS = {
        "\010" =>  '\b',
        "\f" =>    '\f',
        "\n" =>    '\n',
        "\r" =>    '\r',
        "\t" =>    '\t',
        '"'  =>    '\"',
        '\\' =>    '\\\\',
        '<'  =>    '\\074',
        '>'  =>    '\\076'
      }
      
      define_encoder String do |string|
        '"' + string.gsub(/[\010\f\n\r\t"\\<>]/) { |s|
          ESCAPED_CHARS[s]
        }.gsub(/([\xC0-\xDF][\x80-\xBF]|
                 [\xE0-\xEF][\x80-\xBF]{2}|
                 [\xF0-\xF7][\x80-\xBF]{3})+/nx) { |s|
          s.unpack("U*").pack("n*").unpack("H*")[0].gsub(/.{4}/, '\\\\u\&')
        } + '"'
      end
      
      define_encoder Numeric do |numeric|
        numeric.to_s
      end
      
      define_encoder Symbol do |symbol|
        symbol.to_s.to_json
      end

      define_encoder Enumerable do |enumerable|
        "[#{enumerable.map { |value| value.to_json } * ', '}]"
      end
      
      define_encoder Hash do |hash|
        returning result = '{' do
          result << hash.map do |key, value|
            key = ActiveSupport::JSON::Variable.new(key.to_s) if 
              ActiveSupport::JSON.can_unquote_identifier?(key)
            "#{key.to_json}: #{value.to_json}"
          end * ', '
          result << '}'
        end
      end

      define_encoder Regexp do |regexp|
        regexp.inspect
      end
    end
  end
end
