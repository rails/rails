# frozen_string_literal: true

module ActionMailer
  module Callbacks
    extend ActiveSupport::Concern

    DEFAULT_INTERNAL_METHODS = [:_run_deliver_callbacks].freeze # :nodoc:

    included do
      define_callbacks :deliver, skip_after_callbacks_if_terminated: true
    end

    module ClassMethods
      [:before, :after, :around].each do |callback|
        define_method "#{callback}_deliver" do |*names, &blk|
          _insert_callbacks(names, blk) do |name, options|
            set_callback(:deliver, callback, name, options)
          end
        end
      end

      def internal_methods # :nodoc:
        super.concat(DEFAULT_INTERNAL_METHODS)
      end
    end
  end
end
