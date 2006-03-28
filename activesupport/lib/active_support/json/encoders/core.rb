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
      
      define_encoder String do |string|
        returning value = '"' do
          string.each_char do |char|
            value << case
            when char == "\010":  '\b'
            when char == "\f":    '\f'
            when char == "\n":    '\n'
            when char == "\r":    '\r'
            when char == "\t":    '\t'
            when char == '"':     '\"'
            when char == '\\':    '\\\\'  
            when char.length > 1: "\\u#{'%04x' % char.unpack('U').first}"
            else;                 char
            end
          end
          value << '"'
        end
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
          result << hash.map do |pair|
            pair.map { |value| value.to_json } * ': '
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
