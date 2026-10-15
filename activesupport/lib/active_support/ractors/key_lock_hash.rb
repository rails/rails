# :markup: markdown
# frozen_string_literal: true

module ActiveSupport
  module Ractors
    if SHARING_AVAILABLE
      require "ractor/keylockhash"
      KeyLockHash = ::Ractor::KeyLockHash
    else
      class KeyLockHash # :nodoc:
        def initialize(initial = nil)
          @hash = initial ? initial.to_h.dup : {}
          @lock = Mutex.new
        end

        def [](key)
          @lock.synchronize { @hash[key] }
        end

        def []=(key, value)
          @lock.synchronize { @hash[key] = value }
        end

        def fetch(key, *default, &block)
          @lock.synchronize do
            return @hash.fetch(key) if @hash.key?(key)
          end

          {}.fetch(key, *default, &block)
        end

        def key?(key)
          @lock.synchronize { @hash.key?(key) }
        end

        def keys
          @lock.synchronize { @hash.keys }
        end

        def to_h
          @lock.synchronize { @hash.dup }
        end

        def update(key)
          @lock.synchronize { @hash[key] = yield @hash[key] }
        end

        def increment(key, by = 1)
          update(key) { |value| (value || 0) + by }
        end

        def delete(key)
          @lock.synchronize { @hash.delete(key) }
        end

        def inspect
          "#<#{self.class.name} #{to_h.inspect}>"
        end
      end
    end
  end
end
