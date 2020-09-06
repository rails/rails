# frozen_string_literal: true

module ActionView #:nodoc:
  # = Action View RawFile Template
  class Template #:nodoc:
    class RawFile #:nodoc:
      attr_accessor :type, :format

      def initialize(filename)
        @filename = filename.to_s
        extname = ::File.extname(filename).delete('.')
        @type = Template::Types[extname] || Template::Types[:text]
        @format = @type.symbol
      end

      def identifier
        @filename
      end

      def render(*args)
        ::File.read(@filename)
      end

      def formats; Array(format); end
      deprecate :formats
    end
  end
end
