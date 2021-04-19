# frozen_string_literal: true

module ActiveRecord
  module AsyncExecution
    def async(method_name, *args)
      validate_record_persistence!
      validate_method_existence!(method_name)
      validate_method_arity!(method_name, args.length)
      ActiveRecord::AsyncJob.perform_later(self, method_name.to_s, *args)
    end

    private

    def validate_record_persistence!
      unless persisted?
        raise ArgumentError, "only persisted records can use #async!"
      end
    end

    def validate_method_existence!(method_name)
      unless respond_to?(method_name)
        raise ArgumentError, "there is no public method `#{method_name}` for #{self}"
      end
    end

    # Suggetions for a better way to do some sanity checks are welcome
    def validate_method_arity!(method_name, arguments_length)
      arity = method(method_name).arity
      min = (arity >= 0) ? arity : (- 1 - arity)
      max = (arity >= 0) ? arity : Float::Infinity

      unless (n = arguments_length).in?(min..max)
        range = (min == max) ? min : max.finite? ? "#{min}..#{max}" : "#{min}.."
        interpolation = "`#{method_name}` - (given #{n}, expected #{range})"
        raise ArgumentError, "wrong number of arguments for #{interpolation}"
      end
    end
  end
end
