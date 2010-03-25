module Arel
  module ObjectExtensions
    def bind(relation)
      Arel::Value.new(self, relation)
    end

    def find_correlate_in(relation)
      bind(relation)
    end

    def let
      yield(self)
    end

    # TODO remove this when ActiveSupport beta1 is out.
    # Returns the object's singleton class.
    def singleton_class
      class << self
        self
      end
    end unless respond_to?(:singleton_class)

    # class_eval on an object acts like singleton_class_eval.
    def class_eval(*args, &block)
      singleton_class.class_eval(*args, &block)
    end

    Object.send(:include, self)
  end
end
