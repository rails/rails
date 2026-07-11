# frozen_string_literal: true

# :markup: markdown

module ActiveRecord
  module ConnectionAdapters
    class RactorConnectionProxy < AbstractAdapter # :nodoc:
      # Request for the main-side `query` operation. Built with `copy: true`
      # when it must cross a Ractor boundary: binds are carried as an internal
      # Marshal payload and the request is made shareable. A main-Ractor
      # caller (self-proxy) keeps the live objects and skips the shareability
      # work entirely; `binds` transparently yields the live objects either
      # way.
      class QueryRequest
        attr_reader :sql, :name, :prepare, :batch, :allow_retry

        def initialize(sql:, name:, binds:, prepare:, batch:, allow_retry:, copy:)
          @prepare = !!prepare
          @batch = !!batch
          @allow_retry = !!allow_retry

          if copy
            @sql = RactorConnectionProxy.shareable_copy(sql)
            @name = RactorConnectionProxy.shareable_copy(name)
            @binds = nil
            @binds_payload = RactorConnectionProxy.dump_binds(binds)
            ActiveSupport::Ractors.make_shareable(self, copy: false)
          else
            @sql = sql
            @name = name
            @binds = binds || []
            @binds_payload = nil
          end
        end

        def binds
          @binds || (@binds_payload ? Marshal.load(@binds_payload) : [])
        end
      end
    end
  end
end
