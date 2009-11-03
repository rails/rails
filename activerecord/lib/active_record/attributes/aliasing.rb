module ActiveRecord
  module Attributes
    module Aliasing
      # Allows access to keys using aliased names.
      #
      # Example:
      # class Attributes < Hash
      #   include Aliasing
      # end
      #
      # attributes = Attributes.new
      # attributes.aliases['id'] = 'fancy_primary_key'
      # attributes['fancy_primary_key'] = 2020
      #
      # attributes['id']
      # => 2020
      #
      # Additionally, symbols are always aliases of strings:
      # attributes[:fancy_primary_key]
      # => 2020
      #
      def [](key)
        super(unalias(key))
      end

      def []=(key, value)
        super(unalias(key), value)
      end

      def aliases
        @aliases ||= {}
      end

      def unalias(key)
        key = key.to_s
        aliases[key] || key
      end

    end
  end
end

