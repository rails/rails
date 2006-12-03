require 'time'
require 'date'
require 'xmlrpc/datetime'

module ActionWebService # :nodoc:
  module Casting # :nodoc:
    class CastingError < ActionWebServiceError # :nodoc:
    end

    # Performs casting of arbitrary values into the correct types for the signature
    class BaseCaster # :nodoc:
      def initialize(api_method)
        @api_method = api_method
      end

      # Coerces the parameters in +params+ (an Enumerable) into the types
      # this method expects
      def cast_expects(params)
        self.class.cast_expects(@api_method, params)
      end

      # Coerces the given +return_value+ into the type returned by this
      # method
      def cast_returns(return_value)
        self.class.cast_returns(@api_method, return_value)
      end

      class << self
        include ActionWebService::SignatureTypes

        def cast_expects(api_method, params) # :nodoc:
          return [] if api_method.expects.nil?
          api_method.expects.zip(params).map{ |type, param| cast(param, type) }
        end

        def cast_returns(api_method, return_value) # :nodoc:
          return nil if api_method.returns.nil?
          cast(return_value, api_method.returns[0])
        end

        def cast(value, signature_type) # :nodoc:
          return value if signature_type.nil? # signature.length != params.length
          return nil if value.nil?
          # XMLRPC protocol doesn't support nil values. It uses false instead.
          # It should never happen for SOAP.
          if signature_type.structured? && value.equal?(false)
            return nil
          end
          unless signature_type.array? || signature_type.structured?
            return value if canonical_type(value.class) == signature_type.type
          end
          if signature_type.array?
            unless value.respond_to?(:entries) && !value.is_a?(String)
              raise CastingError, "Don't know how to cast #{value.class} into #{signature_type.type.inspect}"
            end
            value.entries.map do |entry|
              cast(entry, signature_type.element_type)
            end
          elsif signature_type.structured?
            cast_to_structured_type(value, signature_type)
          elsif !signature_type.custom?
            cast_base_type(value, signature_type)
          end
        end

        def cast_base_type(value, signature_type) # :nodoc:
          # This is a work-around for the fact that XML-RPC special-cases DateTime values into its own DateTime type
          # in order to support iso8601 dates. This doesn't work too well for us, so we'll convert it into a Time,
          # with the caveat that we won't be able to handle pre-1970 dates that are sent to us.
          # 
          # See http://dev.rubyonrails.com/ticket/2516
          value = value.to_time if value.is_a?(XMLRPC::DateTime)

          case signature_type.type
          when :int
            Integer(value)
          when :string
            value.to_s
          when :base64
            if value.is_a?(ActionWebService::Base64)
              value
            else
              ActionWebService::Base64.new(value.to_s)
            end
          when :bool
            return false if value.nil?
            return value if value == true || value == false
            case value.to_s.downcase
            when '1', 'true', 'y', 'yes'
              true
            when '0', 'false', 'n', 'no'
              false
            else
              raise CastingError, "Don't know how to cast #{value.class} into Boolean"
            end
          when :float
            Float(value)
          when :decimal
            BigDecimal(value.to_s)
          when :time
            value = "%s/%s/%s %s:%s:%s" % value.values_at(*%w[2 3 1 4 5 6]) if value.kind_of?(Hash)
            value.kind_of?(Time) ? value : Time.parse(value.to_s)
          when :date
            value = "%s/%s/%s" % value.values_at(*%w[2 3 1]) if value.kind_of?(Hash)
            value.kind_of?(Date) ? value : Date.parse(value.to_s)
          when :datetime
            value = "%s/%s/%s %s:%s:%s" % value.values_at(*%w[2 3 1 4 5 6]) if value.kind_of?(Hash)
            value.kind_of?(DateTime) ? value : DateTime.parse(value.to_s)
          end
        end

        def cast_to_structured_type(value, signature_type) # :nodoc:
          obj = nil
          obj = value if canonical_type(value.class) == canonical_type(signature_type.type)
          obj ||= signature_type.type_class.new
          if value.respond_to?(:each_pair)
            klass = signature_type.type_class
            value.each_pair do |name, val|
              type = klass.respond_to?(:member_type) ? klass.member_type(name) : nil
              val = cast(val, type) if type
              # See http://dev.rubyonrails.com/ticket/3567
              val = val.to_time if val.is_a?(XMLRPC::DateTime)
              obj.__send__("#{name}=", val) if obj.respond_to?(name)
            end
          elsif value.respond_to?(:attributes)
            signature_type.each_member do |name, type|
              val = value.__send__(name)
              obj.__send__("#{name}=", cast(val, type)) if obj.respond_to?(name)
            end
          else
            raise CastingError, "Don't know how to cast #{value.class} to #{signature_type.type_class}"
          end
          obj
        end
      end
    end
  end
end
