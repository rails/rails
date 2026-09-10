# frozen_string_literal: true

# :markup: markdown

module ActiveRecord
  module ConnectionAdapters
    class RactorConnectionProxy < AbstractAdapter # :nodoc:
      # Request for the main-side `query` operation. Always built
      # boundary-safe — binds are carried as an internal Marshal payload and
      # the request is made shareable — whether or not it crosses a Ractor
      # boundary, so a self-proxy run behaves exactly like a worker run.
      class QueryRequest
        attr_reader :sql, :name, :prepare, :batch, :allow_retry

        def initialize(sql:, name:, binds:, prepare:, batch:, allow_retry:)
          @prepare = !!prepare
          @batch = !!batch
          @allow_retry = !!allow_retry
          @sql = RactorConnectionProxy.shareable_copy(sql)
          @name = RactorConnectionProxy.shareable_copy(name)
          @binds_payload = RactorConnectionProxy.dump_binds(binds)
          ActiveSupport::Ractors.make_shareable(self, copy: false)
        end

        def binds
          @binds_payload ? Marshal.load(@binds_payload) : []
        end
      end
    end
  end
end
