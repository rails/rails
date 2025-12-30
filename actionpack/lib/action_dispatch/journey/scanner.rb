# frozen_string_literal: true

# :markup: markdown

require "strscan"

module ActionDispatch
  module Journey # :nodoc:
    class Scanner # :nodoc:
      STATIC_TOKENS = Array.new(150)
      STATIC_TOKENS[".".ord] = :DOT
      STATIC_TOKENS["/".ord] = :SLASH
      STATIC_TOKENS["(".ord] = :LPAREN
      STATIC_TOKENS[")".ord] = :RPAREN
      STATIC_TOKENS["|".ord] = :OR
      STATIC_TOKENS[":".ord] = :SYMBOL
      STATIC_TOKENS["*".ord] = :STAR
      STATIC_TOKENS.freeze

      class Scanner < StringScanner
        unless method_defined?(:peek_byte) # https://github.com/ruby/strscan/pull/89
          def peek_byte
            string.getbyte(pos)
          end
        end
      end

      def initialize
        @scanner = nil
        @length = nil
      end

      def scan_setup(str)
        @scanner = Scanner.new(str)
      end

      def next_token
        return if @scanner.eos?

        until token = scan || @scanner.eos?; end
        token
      end

      def last_string
        -@scanner.string.byteslice(@scanner.pos - @length, @length)
      end

      def last_literal
        last_str = @scanner.string.byteslice(@scanner.pos - @length, @length)
        last_str.tr! "\\", ""
        -last_str
      end

      private
        def scan
          next_byte = @scanner.peek_byte
          case
          when (token = STATIC_TOKENS[next_byte]) && (token != :SYMBOL || next_byte_is_not_a_token?)
            @scanner.pos += 1
            @length = @scanner.skip(/\w+/).to_i + 1 if token == :SYMBOL || token == :STAR
            token
          when @length = @scanner.skip(/(?:[\w%\-~!$&'*+,;=@]|\\[:()])+/)
            :LITERAL
          when @length = @scanner.skip(/./)
            :LITERAL
          end
        end

        def next_byte_is_not_a_token?
          !STATIC_TOKENS[@scanner.string.getbyte(@scanner.pos + 1)]
        end
    end
  end
end
