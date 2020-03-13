# frozen_string_literal: true

require "active_support/concern"
require "active_support/core_ext/module/attribute_accessors_per_thread"
require "active_support/core_ext/module/delegation"
require "active_support/core_ext/object/try"

module ActionText
  module Rendering #:nodoc:
    extend ActiveSupport::Concern

    included do
      thread_cattr_accessor :renderer, instance_accessor: false

      singleton_class.delegate :render, to: :current_renderer
      delegate :render, to: :class
    end

    class_methods do
      def current_renderer
        # Memoize the current renderer since it may be used many times
        # per request and costs a fair bit to create.
        #
        # Memoize on Current so it's automatically cleaned up after
        # requests/jobs finish.
        ::ActionText::Current.renderer_for_current_request ||= renderer.try(:current) || renderer
      end
    end
  end
end
