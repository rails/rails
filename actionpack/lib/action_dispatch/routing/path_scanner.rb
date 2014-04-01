require 'strscan'

module ActionDispatch
  module Routing # :nodoc:
    class PathScanner # :nodoc:
      def initialize(string)
        @ss      = StringScanner.new(string)
        @nesting = 0
      end

      def scan
        string = _scan
        { required: @nesting.zero?, value: string } if string
      end

      def next_segment_required?
        !@ss.check(/\(/) && !finished?
      end

      def finished?
        @ss.eos? || !!@ss.check(/\)+\Z/)
      end

      private
        def _scan
          case
          when @ss.bol? && @ss.scan(/\//)
            ''
          when @ss.scan(/\//)
            _scan
          when text = @ss.scan(/[:\*\.]+[\w-]+/)
            text
          when @ss.scan(/\(/)
            @nesting += 1
            _scan
          when @ss.scan(/\)/)
            @nesting -= 1
            _scan
          when text = @ss.scan(/\w+\|\w+/)
            text
          when text = @ss.scan(/[\:\w%\-~]+/)
            text
          when text = @ss.scan(/./)
            text
          end
        end

    end
  end
end
