# frozen_string_literal: true

module ActiveSupport
  # Provides a Ruby 4.0-compatible +inspect+ method for Ruby < 4.0.
  #
  # Ruby 4.0 introduced +instance_variables_to_inspect+, which lets classes
  # control which instance variables appear in +inspect+ output without
  # overriding +inspect+ entirely. This module backports that behavior so
  # classes can define +instance_variables_to_inspect+ on any Ruby version.
  #
  #   class MyClass
  #     include ActiveSupport::InspectBackport if RUBY_VERSION < "4"
  #
  #     private
  #       def instance_variables_to_inspect
  #         [:@name, :@status].freeze
  #       end
  #   end
  module InspectBackport # :nodoc:
    def inspect
      ivars = instance_variables_to_inspect
      klass = self.class.name || self.class.inspect
      addr = "0x%x" % object_id

      if ivars.empty?
        "#<#{klass}:#{addr}>"
      else
        pairs = ivars.map { |ivar| "#{ivar}=#{instance_variable_get(ivar).inspect}" }
        "#<#{klass}:#{addr} #{pairs.join(", ")}>"
      end
    end
  end
end
