module ActiveResource
  module Observing
    extend ActiveSupport::Concern
    include ActiveModel::Observing

    included do
      %w( create save update destroy ).each do |method|
        class_eval(<<-EOS, __FILE__, __LINE__ + 1)
          def #{method}_with_notifications(*args, &block)
            notify_observers(:before_#{method})
            if result = #{method}_without_notifications(*args, &block)
              notify_observers(:after_#{method})
            end
            result
          end
        EOS
        alias_method_chain(method, :notifications)
      end
    end
  end
end
