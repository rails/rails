# frozen_string_literal: true

require "strscan"

module ActionDispatch
  module Journey # :nodoc:
    class Scanner # :nodoc:
      def initialize
        @ss = nil
      end

      def scan_setup(str)
        @ss = StringScanner.new(str)
      end

      def eos?
        @ss.eos?
      end

      def pos
        @ss.pos
      end

      def pre_match
        @ss.pre_match
      end

      def next_token
        return if @ss.eos?

        until token = scan || @ss.eos?; end
        token
      end

      private

        def scan
          case
            # /
          when @ss.skip(/\//)
            [:SLASH, "/"]
          when @ss.skip(/\(/)
            [:LPAREN, "("]
          when @ss.skip(/\)/)
            [:RPAREN, ")"]
          when @ss.skip(/\|/)
            [:OR, "|"]
          when @ss.skip(/\./)
            [:DOT, "."]
          when text = @ss.scan(/:\w+/)
            [:SYMBOL, text]
          when text = @ss.scan(/\*\w+/)
            [:STAR, text]
          when text = @ss.scan(/(?:[\w%\-~!$&'*+,;=@]|\\[:()])+/)
            text.tr! "\\", ""
            [:LITERAL, text]
            # any char
          when text = @ss.scan(/./)
            [:LITERAL, text]
          end
        end
    end
  end
end
