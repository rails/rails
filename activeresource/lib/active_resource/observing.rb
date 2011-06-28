module ActiveResource
  module Observing
    extend ActiveSupport::Concern
    include ActiveModel::Observing

    included do
      %w( create save update destroy ).each do |method|
        # def create_with_notifications(*args, &block)
        #   notify_observers(:before_create)
        #   if result = create_without_notifications(*args, &block)
        #     notify_observers(:after_create)
        #   end
        #   result
        # end
        # alias_method_chain(create, :notifications)
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
