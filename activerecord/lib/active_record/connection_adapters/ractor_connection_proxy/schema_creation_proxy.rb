# frozen_string_literal: true

# :markup: markdown

module ActiveRecord
  module ConnectionAdapters
    class RactorConnectionProxy < AbstractAdapter # :nodoc:
      # Renders schema definition objects (e.g. CreateIndexDefinition)
      # through the token-pinned connection's own SchemaCreation visitor.
      class SchemaCreationProxy
        def initialize(proxy)
          @proxy = proxy
        end

        def accept(node)
          @proxy.remote_schema_creation_accept(node)
        end
      end
    end
  end
end
