# frozen_string_literal: true

require "active_support/concern"
require "active_support/core_ext/module/attribute_accessors_per_thread"

module ActionText
  module Rendering #:nodoc:
    extend ActiveSupport::Concern

    included do
      cattr_accessor :default_renderer, instance_accessor: false
      thread_cattr_accessor :renderer, instance_accessor: false
      delegate :render, to: :class
    end

    class_methods do
      def with_renderer(renderer)
        previous_renderer = self.renderer
        self.renderer = renderer
        yield
      ensure
        self.renderer = previous_renderer
      end

      def render(*args, &block)
        (renderer || default_renderer).render_to_string(*args, &block)
      end
    end
  end
end
