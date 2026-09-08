# frozen_string_literal: true

# :markup: markdown

require "active_support/core_ext/module/attribute_accessors_per_thread"

module ActionText
  module Rendering # :nodoc:
    extend ActiveSupport::Concern

    included do
      thread_cattr_accessor :renderer, instance_accessor: false
      delegate :render, to: :class
    end

    class_methods do
      def action_controller_renderer
        @action_controller_renderer ||= Class.new(ActionController::Base).renderer
      end

      def with_renderer(renderer)
        previous_renderer = self.renderer
        self.renderer = renderer
        yield
      ensure
        self.renderer = previous_renderer
      end

      def render(*args, &block)
        (renderer || action_controller_renderer).render_to_string(*args, &block)
      end
    end
  end
end
