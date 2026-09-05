# frozen_string_literal: true

# :markup: markdown

module ActiveRecord
  module ConnectionAdapters
    class RactorConnectionProxy < AbstractAdapter # :nodoc:
      # Compiles Arel on the main Ractor through the token-pinned connection's
      # own visitor, so dialect-specific SQL generation (and its collector
      # semantics) is never approximated on the worker.
      class VisitorProxy
        def initialize(proxy)
          @proxy = proxy
        end

        def compile(node, collector = nil)
          @proxy.remote_visitor_compile(node, collector)
        end

        def accept(node, collector = nil)
          sql = @proxy.remote_visitor_compile(node, nil)
          if collector
            collector << sql
            collector
          else
            sql
          end
        end
      end
    end
  end
end
