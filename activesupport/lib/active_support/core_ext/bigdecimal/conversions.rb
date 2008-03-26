require 'yaml'

module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module BigDecimal #:nodoc:
      module Conversions
        def self.included(base) #:nodoc:
          base.instance_eval do
            alias_method :_original_to_s, :to_s
            alias_method :to_s, :to_formatted_s
          end
        end
        
        def to_formatted_s(format="F")
          _original_to_s(format)
        end
        
        yaml_as "tag:yaml.org,2002:float"
        def to_yaml( opts = {} )
          YAML::quick_emit( nil, opts ) do |out|
            # This emits the number without any scientific notation.
            # I prefer it to using self.to_f.to_s, which would lose precision.
            #
            # Note that YAML allows that when reconsituting floats
            # to native types, some precision may get lost.
            # There is no full precision real YAML tag that I am aware of.
            str = self.to_s
            if str == "Infinity"
              str = ".Inf"
            elsif str == "-Infinity"
              str = "-.Inf"
            elsif str == "NaN"
              str = ".NaN"
            end
            out.scalar( "tag:yaml.org,2002:float", str, :plain )
          end
        end
      end
    end
  end
end
