# frozen_string_literal: true

module RuboCop
  module Linters
    class DigestWithOpenSSL < RuboCop::Cop::Base
      MSG = "Digest may only be called from OpenSSL"

      def_node_matcher :digest_open_call?, <<~PATTERN
        (const nil? :Digest)
      PATTERN

      def on_const(node)
        return unless digest_open_call?(node)
        add_offense(node)
      end
    end
  end
end
