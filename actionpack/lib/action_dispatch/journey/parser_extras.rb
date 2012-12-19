require 'action_dispatch/journey/scanner'
require 'action_dispatch/journey/nodes/node'

module ActionDispatch
  module Journey
    class Parser < Racc::Parser
      include Journey::Nodes

      def initialize
        @scanner = Scanner.new
      end

      def parse string
        @scanner.scan_setup string
        do_parse
      end

      def next_token
        @scanner.next_token
      end
    end
  end
end
