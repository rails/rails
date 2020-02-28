# frozen_string_literal: true

module ActiveRecord
  class DatabaseConfigurations
    class Builder < BasicObject
      class BlockContext < BasicObject
        attr_reader :hash

        def initialize(config, hash) # :nodoc:
          @config = config
          @hash = hash
        end

        # Builds a HashConfig and adds it to the configurations list.
        def shard(*args, &blk)
          @config.shard(*args, &blk)
        end

        # Builds a HashConfig as a replica and adds it to the configurations
        # list.
        def replica(*args, &blk)
          @config.replica(*args, &blk)
        end

        def method_missing(k, v) # :nodoc:
          @hash[k] = v
        end
      end
    end
  end
end
