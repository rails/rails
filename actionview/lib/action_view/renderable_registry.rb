# frozen_string_literal: true

module ActionView # :nodoc:
  module RenderableRegistry # :nodoc:
    @renderables_by_class = Hash.new({})

    def self.get_renderables(klass)
      @renderables_by_class[klass] || get_renderables(klass.superclass)
    end

    def self.set_renderable(klass, path, renderable_klass)
      @renderables_by_class[klass][path] = renderable_klass
    end
  end
end
