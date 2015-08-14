require 'action_dispatch/journey/scanner'
require 'action_dispatch/journey/nodes/node'

module ActionDispatch
  module Journey # :nodoc:
    class Parser < Racc::Parser # :nodoc:
      include Journey::Nodes

      def self.parse(string)
        new.parse string
      end

      def initialize
        @scanner = Scanner.new
      end

      def parse(string)
        @scanner.scan_setup(string)
        do_parse
      end

      def next_token
        @scanner.next_token
      end
    end
  end
end
