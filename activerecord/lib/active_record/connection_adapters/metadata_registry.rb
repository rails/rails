# frozen_string_literal: true

require "digest/md5"

module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module MetadataRegistry
      REGISTRY = {}

      class << self
        def fetch(type, *args)
          key = Digest::MD5.hexdigest(Marshal.dump([type.name, args]))
          REGISTRY[key] ||= yield.freeze
        end
      end

      module Concern
        def new(*args)
          MetadataRegistry.fetch(self, *args) { super }
        end
      end
    end
  end
end
