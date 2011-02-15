require 'action_view/renderer/abstract_renderer'

module ActionView
  class PartialRenderer < AbstractRenderer #:nodoc:
    PARTIAL_NAMES = Hash.new {|h,k| h[k] = {} }

    def initialize(view)
      super
      @partial_names = PARTIAL_NAMES[@view.controller.class.name]
    end

    def setup(options, block)
      partial = options[:partial]

      @options = options
      @locals  = options[:locals] || {}
      @block   = block

      if String === partial
        @object     = options[:object]
        @path       = partial
        @collection = collection
      else
        @object = partial

        if @collection = collection_from_object || collection
          paths = @collection_data = @collection.map { |o| partial_path(o) }
          @path = paths.uniq.size == 1 ? paths.first : nil
        else
          @path = partial_path
        end
      end

      if @path
        @variable, @variable_counter = retrieve_variable(@path)
      else
        paths.map! { |path| retrieve_variable(path).unshift(path) }
      end

      self
    end

    def render
      wrap_formats(@path) do
        identifier = ((@template = find_partial) ? @template.identifier : @path)

        if @collection
          instrument(:collection, :identifier => identifier || "collection", :count => @collection.size) do
            render_collection
          end
        else
          instrument(:partial, :identifier => identifier) do
            render_partial
          end
        end
      end
    end

    def render_collection
      return nil if @collection.blank?

      if @options.key?(:spacer_template)
        spacer = find_template(@options[:spacer_template]).render(@view, @locals)
      end

      result = @template ? collection_with_template : collection_without_template
      result.join(spacer).html_safe
    end

    def render_partial
      locals, view, block = @locals, @view, @block
      object, as = @object, @variable

      if !block && (layout = @options[:layout])
        layout = find_template(layout)
      end

      object ||= locals[as]
      locals[as] = object

      content = @template.render(view, locals) do |*name|
        view._layout_for(*name, &block)
      end

      content = layout.render(view, locals){ content } if layout
      content
    end

    private

    def collection
      if @options.key?(:collection)
        collection = @options[:collection]
        collection.respond_to?(:to_ary) ? collection.to_ary : []
      end
    end

    def collection_from_object
      if @object.respond_to?(:to_ary)
        @object.to_ary
      end
    end

    def find_partial
      if path = @path
        locals = @locals.keys
        locals << @variable
        locals << @variable_counter if @collection
        find_template(path, locals)
      end
    end

    def find_template(path=@path, locals=@locals.keys)
      prefixes = path.include?(?/) ? [] : @view.controller_prefixes
      @lookup_context.find_template(path, prefixes, true, locals)
    end

    def collection_with_template
      segments, locals, template = [], @locals, @template
      as, counter = @variable, @variable_counter

      locals[counter] = -1

      @collection.each do |object|
        locals[counter] += 1
        locals[as] = object
        segments << template.render(@view, locals)
      end

      segments
    end

    def collection_without_template
      segments, locals, collection_data = [], @locals, @collection_data
      index, template, cache = -1, nil, {}
      keys = @locals.keys

      @collection.each_with_index do |object, i|
        path, *data = collection_data[i]
        template = (cache[path] ||= find_template(path, keys + data))
        locals[data[0]] = object
        locals[data[1]] = (index += 1)
        segments << template.render(@view, locals)
      end

      @template = template
      segments
    end

    def partial_path(object = @object)
      @partial_names[object.class.name] ||= begin
        object = object.to_model if object.respond_to?(:to_model)

        object.class.model_name.partial_path.dup.tap do |partial|
          path = @view.controller_prefixes.first
          partial.insert(0, "#{File.dirname(path)}/") if partial.include?(?/) && path.include?(?/)
        end
      end
    end

    def retrieve_variable(path)
      variable = @options[:as].try(:to_sym) || path[%r'_?(\w+)(\.\w+)*$', 1].to_sym
      variable_counter = :"#{variable}_counter" if @collection
      [variable, variable_counter]
    end
  end
end
