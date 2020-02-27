# frozen_string_literal: true

require "action_view/renderer/partial_renderer"

module ActionView
  class PartialIteration
    # The number of iterations that will be done by the partial.
    attr_reader :size

    # The current iteration of the partial.
    attr_reader :index

    def initialize(size)
      @size  = size
      @index = 0
    end

    # Check if this is the first iteration of the partial.
    def first?
      index == 0
    end

    # Check if this is the last iteration of the partial.
    def last?
      index == size - 1
    end

    def iterate! # :nodoc:
      @index += 1
    end
  end

  class CollectionRenderer < PartialRenderer # :nodoc:
    include ObjectRendering

    class CollectionIterator # :nodoc:
      include Enumerable

      attr_reader :collection

      def initialize(collection)
        @collection = collection
      end

      def each(&blk)
        @collection.each(&blk)
      end

      def size
        @collection.size
      end
    end

    class SameCollectionIterator < CollectionIterator # :nodoc:
      def initialize(collection, path, variables)
        super(collection)
        @path      = path
        @variables = variables
      end

      def from_collection(collection)
        return collection if collection == self
        self.class.new(collection, @path, @variables)
      end

      def each_with_info
        return enum_for(:each_with_info) unless block_given?
        variables = [@path] + @variables
        @collection.each { |o| yield(o, variables) }
      end
    end

    class MixedCollectionIterator < CollectionIterator # :nodoc:
      def initialize(collection, paths)
        super(collection)
        @paths = paths
      end

      def each_with_info
        return enum_for(:each_with_info) unless block_given?
        collection.each_with_index { |o, i| yield(o, @paths[i]) }
      end
    end

    def render_collection_with_partial(collection, partial, context, block)
      collection = build_collection_iterator(collection, partial, context)

      if @options[:cached] && !partial
        raise NotImplementedError, "render caching requires a template. Please specify a partial when rendering"
      end

      template = find_template(partial, template_keys(partial)) if partial

      if !block && (layout = @options[:layout])
        layout = find_template(layout.to_s, template_keys(partial))
      end

      render_collection(collection, context, template, partial, layout)
    end

    def render_collection_derive_partial(collection, context, block)
      paths = collection.map { |o| partial_path(o, context) }

      if paths.uniq.length == 1
        # Homogeneous
        render_collection_with_partial(collection, paths.first, context, block)
      else
        render_collection_with_partial(collection, nil, context, block)
      end
    end

    private
      def retrieve_variable(path)
        vars = super
        variable = vars.first
        vars << :"#{variable}_counter"
        vars << :"#{variable}_iteration"
        vars
      end

      def build_collection_iterator(collection, path, context)
        if path
          SameCollectionIterator.new(collection, path, retrieve_variable(path))
        else
          paths = collection.map { |o| partial_path(o, context) }
          paths.map! { |path| retrieve_variable(path).unshift(path) }
          MixedCollectionIterator.new(collection, paths)
        end
      end

      def render_collection(collection, view, template, path, layout)
        identifier = (template && template.identifier) || path
        instrument(:collection, identifier: identifier, count: collection.size) do |payload|
          spacer = if @options.key?(:spacer_template)
            spacer_template = find_template(@options[:spacer_template], @locals.keys)
            build_rendered_template(spacer_template.render(view, @locals), spacer_template)
          else
            RenderedTemplate::EMPTY_SPACER
          end

          collection_body = if template
            cache_collection_render(payload, view, template, collection) do |collection|
              collection_with_template(view, template, layout, collection)
            end
          else
            collection_with_template(view, nil, layout, collection)
          end

          return RenderedCollection.empty(@lookup_context.formats.first) if collection_body.empty?

          build_rendered_collection(collection_body, spacer)
        end
      end

      def collection_with_template(view, template, layout, collection)
        locals = @locals
        cache = template || {}

        partial_iteration = PartialIteration.new(collection.size)

        collection.each_with_info.map do |object, (path, as, counter, iteration)|
          index = partial_iteration.index

          locals[as]        = object
          locals[counter]   = index
          locals[iteration] = partial_iteration

          _template = template || (cache[path] ||= find_template(path, @locals.keys + [as, counter, iteration]))
          content = _template.render(view, locals)
          content = layout.render(view, locals) { content } if layout
          partial_iteration.iterate!
          build_rendered_template(content, _template)
        end
      end
  end
end
