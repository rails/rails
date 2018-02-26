# frozen_string_literal: true

module ActiveRecord
  module AttributeMethods
    module Read
      extend ActiveSupport::Concern

      # Returns the value of the attribute identified by <tt>attr_name</tt> after
      # it has been typecast (for example, "2004-12-12" in a date column is cast
      # to a date object, like Date.new(2004, 12, 12)).
      def read_attribute(attr_name, &block)
        name = if self.class.attribute_alias?(attr_name)
          self.class.attribute_alias(attr_name).to_s
        else
          attr_name.to_s
        end

        primary_key = self.class.primary_key
        name = primary_key if name == "id".freeze && primary_key
        sync_with_transaction_state if name == primary_key
        _read_attribute(name, &block)
      end

      # This method exists to avoid the expensive primary_key check internally, without
      # breaking compatibility with the read_attribute API
      if defined?(JRUBY_VERSION)
        # This form is significantly faster on JRuby, and this is one of our biggest hotspots.
        # https://github.com/jruby/jruby/pull/2562
        def _read_attribute(attr_name, &block) # :nodoc
          @attributes.fetch_value(attr_name.to_s, &block)
        end
      else
        def _read_attribute(attr_name) # :nodoc:
          @attributes.fetch_value(attr_name.to_s) { |n| yield n if block_given? }
        end
      end

      alias :attribute :_read_attribute
      private :attribute
    end
  end
end
