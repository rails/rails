# frozen_string_literal: true

module Callable
  module Parameters
    # Returns true if the specified parameters satisfy the callable signature,
    # i.e. if arity and keyword parameters match.
    #
    # If the parameters are valid, the callable can be invoked with these parameters
    # raising an +ArgumentError+. This does not include +ArgumentError+ raised
    # explicitly inside the callable.
    def parameters_valid?(*args, **kwargs)
      summary = parameter_summary
      count = args.count

      if kwargs.any? && summary[:key].none?
        count += 1
        kwargs = {}
      end

      if count < summary[:min]
        return false
      end

      if count > summary[:max] && !summary[:rest]
        return false
      end

      keys = kwargs.keys

      missing = summary[:keyreq] - keys
      if missing.any?
        return false
      end

      unless summary[:keyrest]
        unknown = keys - summary[:key]
        if unknown.any?
          return false
        end
      end

      true
    end

    # Raises +ArgumentError+ if the specified parameters do not satisfy the callable
    # signature, i.e. if arity and keyword parameters do not match.
    def validate_parameters(...)
      unless parameters_valid?(...)
        # This will fail but call it anyway to make Ruby raise an ArgumentError
        # with an appropriate error message.
        call(...)

        # If the above did not raise as expected, there is a bug in parameters_valid?.
        # Raise an exception to alert the user that this callable was invoked unintentionally.
        raise "parameters_valid? not in sync with call - #{self.class} has been invoked!"
      end
    end

    private
      def parameter_summary
        @parameter_summary ||= begin
          summary = {
            min: 0,
            max: 0,
            rest: false,
            keyrest: false,
            key: [],
            keyreq: [],
          }

          parameters.each_with_object(summary) do |parameter, summary|
            type, name = parameter
            case type
            when :opt
              summary[:max] += 1
            when :req
              summary[:min] += 1
              summary[:max] += 1
            when :keyreq
              summary[:key] << name
              summary[:keyreq] << name
            when :key
              summary[:key] << name
            when :rest
              summary[:rest] = true
            when :keyrest
              summary[:keyrest] = true
            when :block
              summary[:block] = true
            when :nokey
              summary[:nokey] = true
            else
              raise "Unknown parameter type: #{type}"
            end
          end
        end.freeze
      end
  end
end
