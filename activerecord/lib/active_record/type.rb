require 'active_record/type/helpers'
require 'active_record/type/value'

require 'active_record/type/big_integer'
require 'active_record/type/binary'
require 'active_record/type/boolean'
require 'active_record/type/date'
require 'active_record/type/date_time'
require 'active_record/type/decimal'
require 'active_record/type/decimal_without_scale'
require 'active_record/type/float'
require 'active_record/type/integer'
require 'active_record/type/serialized'
require 'active_record/type/string'
require 'active_record/type/text'
require 'active_record/type/time'
require 'active_record/type/unsigned_integer'

require 'active_record/type/adapter_specific_registry'
require 'active_record/type/type_map'
require 'active_record/type/hash_lookup_type_map'

module ActiveRecord
  module Type
    @registry = AdapterSpecificRegistry.new

    class << self
      attr_accessor :registry # :nodoc:

      def register(*args)
        registry.register(*args)
      end

      def lookup(*args, adapter: current_adapter_name, **kwargs)
        registry.lookup(*args, adapter: adapter, **kwargs)
      end

      private

      def current_adapter_name
        ActiveRecord::Base.connection.adapter_name.downcase.to_sym
      end
    end
  end
end
