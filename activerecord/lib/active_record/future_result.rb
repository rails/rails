# frozen_string_literal: true

require "active_record/connection_adapters/query_intent"

module ActiveRecord
  class FutureResult # :nodoc:
    class Complete
      attr_reader :result
      delegate :empty?, :to_a, to: :result

      def initialize(result)
        @result = result
      end

      def pending?
        false
      end

      def canceled?
        false
      end

      def then(&block)
        Promise::Complete.new(@result.then(&block))
      end
    end

    Canceled = Class.new(ActiveRecordError)

    def self.wrap(result)
      case result
      when self, Complete
        result
      else
        Complete.new(result)
      end
    end

    delegate :empty?, :to_a, to: :result
    delegate :lock_wait, to: :@intent

    def initialize(intent)
      @intent = intent
    end

    def then(&block)
      Promise.new(self, block)
    end

    def cancel
      @intent.cancel
    end

    def result
      raise Canceled if canceled?

      @intent.cast_result
    end

    def pending?
      @intent.pending?
    end

    def canceled?
      @intent.canceled?
    end
  end
end
