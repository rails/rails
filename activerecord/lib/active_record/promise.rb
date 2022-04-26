# frozen_string_literal: true

module ActiveRecord
  class Promise < BasicObject
    undef_method :==, :!, :!=

    def initialize(future_result, block) # :nodoc:
      @future_result = future_result
      @block = block
    end

    # Returns whether the associated query is still being executed or not.
    def pending?
      @future_result.pending?
    end

    # Returns the query result.
    # If the query wasn't completed yet, accessing +#value+ will block until the query completes.
    # If the query failed, +#value+ will raise the corresponding error.
    def value
      return @value if defined? @value

      result = @future_result.result
      @value = if @block
        @block.call(result)
      else
        result
      end
    end

    # Returns a new +ActiveRecord::Promise+ that will apply the passed block
    # when the value is accessed:
    #
    #   Post.async_pluck(:title).then { |title| title.upcase }.value
    #   # => "POST TITLE"
    def then(&block)
      Promise.new(@future_result, @block ? @block >> block : block)
    end

    [:class, :respond_to?, :is_a?].each do |method|
      define_method(method, ::Object.instance_method(method))
    end

    def inspect # :nodoc:
      "#<ActiveRecord::Promise status=#{status}>"
    end

    def pretty_print(q) # :nodoc:
      q.text(inspect)
    end

    private
      def status
        if @future_result.pending?
          :pending
        elsif @future_result.canceled?
          :canceled
        else
          :complete
        end
      end

      class Complete < self # :nodoc:
        attr_reader :value

        def initialize(value)
          @value = value
        end

        def then
          Complete.new(yield @value)
        end

        def pending?
          false
        end

        private
          def status
            :complete
          end
      end
  end
end
