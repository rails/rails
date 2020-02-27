# frozen_string_literal: true

require "action_view/renderer/partial_renderer/collection_caching"

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

  # = Action View Partials
  #
  # There's also a convenience method for rendering sub templates within the current controller that depends on a
  # single object (we call this kind of sub templates for partials). It relies on the fact that partials should
  # follow the naming convention of being prefixed with an underscore -- as to separate them from regular
  # templates that could be rendered on their own.
  #
  # In a template for Advertiser#account:
  #
  #  <%= render partial: "account" %>
  #
  # This would render "advertiser/_account.html.erb".
  #
  # In another template for Advertiser#buy, we could have:
  #
  #   <%= render partial: "account", locals: { account: @buyer } %>
  #
  #   <% @advertisements.each do |ad| %>
  #     <%= render partial: "ad", locals: { ad: ad } %>
  #   <% end %>
  #
  # This would first render <tt>advertiser/_account.html.erb</tt> with <tt>@buyer</tt> passed in as the local variable +account+, then
  # render <tt>advertiser/_ad.html.erb</tt> and pass the local variable +ad+ to the template for display.
  #
  # == The :as and :object options
  #
  # By default ActionView::PartialRenderer doesn't have any local variables.
  # The <tt>:object</tt> option can be used to pass an object to the partial. For instance:
  #
  #   <%= render partial: "account", object: @buyer %>
  #
  # would provide the <tt>@buyer</tt> object to the partial, available under the local variable +account+ and is
  # equivalent to:
  #
  #   <%= render partial: "account", locals: { account: @buyer } %>
  #
  # With the <tt>:as</tt> option we can specify a different name for said local variable. For example, if we
  # wanted it to be +user+ instead of +account+ we'd do:
  #
  #   <%= render partial: "account", object: @buyer, as: 'user' %>
  #
  # This is equivalent to
  #
  #   <%= render partial: "account", locals: { user: @buyer } %>
  #
  # == \Rendering a collection of partials
  #
  # The example of partial use describes a familiar pattern where a template needs to iterate over an array and
  # render a sub template for each of the elements. This pattern has been implemented as a single method that
  # accepts an array and renders a partial by the same name as the elements contained within. So the three-lined
  # example in "Using partials" can be rewritten with a single line:
  #
  #   <%= render partial: "ad", collection: @advertisements %>
  #
  # This will render <tt>advertiser/_ad.html.erb</tt> and pass the local variable +ad+ to the template for display. An
  # iteration object will automatically be made available to the template with a name of the form
  # +partial_name_iteration+. The iteration object has knowledge about which index the current object has in
  # the collection and the total size of the collection. The iteration object also has two convenience methods,
  # +first?+ and +last?+. In the case of the example above, the template would be fed +ad_iteration+.
  # For backwards compatibility the +partial_name_counter+ is still present and is mapped to the iteration's
  # +index+ method.
  #
  # The <tt>:as</tt> option may be used when rendering partials.
  #
  # You can specify a partial to be rendered between elements via the <tt>:spacer_template</tt> option.
  # The following example will render <tt>advertiser/_ad_divider.html.erb</tt> between each ad partial:
  #
  #   <%= render partial: "ad", collection: @advertisements, spacer_template: "ad_divider" %>
  #
  # If the given <tt>:collection</tt> is +nil+ or empty, <tt>render</tt> will return +nil+. This will allow you
  # to specify a text which will be displayed instead by using this form:
  #
  #   <%= render(partial: "ad", collection: @advertisements) || "There's no ad to be displayed" %>
  #
  # == \Rendering shared partials
  #
  # Two controllers can share a set of partials and render them like this:
  #
  #   <%= render partial: "advertisement/ad", locals: { ad: @advertisement } %>
  #
  # This will render the partial <tt>advertisement/_ad.html.erb</tt> regardless of which controller this is being called from.
  #
  # == \Rendering objects that respond to +to_partial_path+
  #
  # Instead of explicitly naming the location of a partial, you can also let PartialRenderer do the work
  # and pick the proper path by checking +to_partial_path+ method.
  #
  #  # @account.to_partial_path returns 'accounts/account', so it can be used to replace:
  #  # <%= render partial: "accounts/account", locals: { account: @account} %>
  #  <%= render partial: @account %>
  #
  #  # @posts is an array of Post instances, so every post record returns 'posts/post' on +to_partial_path+,
  #  # that's why we can replace:
  #  # <%= render partial: "posts/post", collection: @posts %>
  #  <%= render partial: @posts %>
  #
  # == \Rendering the default case
  #
  # If you're not going to be using any of the options like collections or layouts, you can also use the short-hand
  # defaults of render to render partials. Examples:
  #
  #  # Instead of <%= render partial: "account" %>
  #  <%= render "account" %>
  #
  #  # Instead of <%= render partial: "account", locals: { account: @buyer } %>
  #  <%= render "account", account: @buyer %>
  #
  #  # @account.to_partial_path returns 'accounts/account', so it can be used to replace:
  #  # <%= render partial: "accounts/account", locals: { account: @account} %>
  #  <%= render @account %>
  #
  #  # @posts is an array of Post instances, so every post record returns 'posts/post' on +to_partial_path+,
  #  # that's why we can replace:
  #  # <%= render partial: "posts/post", collection: @posts %>
  #  <%= render @posts %>
  #
  # == \Rendering partials with layouts
  #
  # Partials can have their own layouts applied to them. These layouts are different than the ones that are
  # specified globally for the entire action, but they work in a similar fashion. Imagine a list with two types
  # of users:
  #
  #   <%# app/views/users/index.html.erb %>
  #   Here's the administrator:
  #   <%= render partial: "user", layout: "administrator", locals: { user: administrator } %>
  #
  #   Here's the editor:
  #   <%= render partial: "user", layout: "editor", locals: { user: editor } %>
  #
  #   <%# app/views/users/_user.html.erb %>
  #   Name: <%= user.name %>
  #
  #   <%# app/views/users/_administrator.html.erb %>
  #   <div id="administrator">
  #     Budget: $<%= user.budget %>
  #     <%= yield %>
  #   </div>
  #
  #   <%# app/views/users/_editor.html.erb %>
  #   <div id="editor">
  #     Deadline: <%= user.deadline %>
  #     <%= yield %>
  #   </div>
  #
  # ...this will return:
  #
  #   Here's the administrator:
  #   <div id="administrator">
  #     Budget: $<%= user.budget %>
  #     Name: <%= user.name %>
  #   </div>
  #
  #   Here's the editor:
  #   <div id="editor">
  #     Deadline: <%= user.deadline %>
  #     Name: <%= user.name %>
  #   </div>
  #
  # If a collection is given, the layout will be rendered once for each item in
  # the collection. For example, these two snippets have the same output:
  #
  #   <%# app/views/users/_user.html.erb %>
  #   Name: <%= user.name %>
  #
  #   <%# app/views/users/index.html.erb %>
  #   <%# This does not use layouts %>
  #   <ul>
  #     <% users.each do |user| -%>
  #       <li>
  #         <%= render partial: "user", locals: { user: user } %>
  #       </li>
  #     <% end -%>
  #   </ul>
  #
  #   <%# app/views/users/_li_layout.html.erb %>
  #   <li>
  #     <%= yield %>
  #   </li>
  #
  #   <%# app/views/users/index.html.erb %>
  #   <ul>
  #     <%= render partial: "user", layout: "li_layout", collection: users %>
  #   </ul>
  #
  # Given two users whose names are Alice and Bob, these snippets return:
  #
  #   <ul>
  #     <li>
  #       Name: Alice
  #     </li>
  #     <li>
  #       Name: Bob
  #     </li>
  #   </ul>
  #
  # The current object being rendered, as well as the object_counter, will be
  # available as local variables inside the layout template under the same names
  # as available in the partial.
  #
  # You can also apply a layout to a block within any template:
  #
  #   <%# app/views/users/_chief.html.erb %>
  #   <%= render(layout: "administrator", locals: { user: chief }) do %>
  #     Title: <%= chief.title %>
  #   <% end %>
  #
  # ...this will return:
  #
  #   <div id="administrator">
  #     Budget: $<%= user.budget %>
  #     Title: <%= chief.name %>
  #   </div>
  #
  # As you can see, the <tt>:locals</tt> hash is shared between both the partial and its layout.
  #
  # If you pass arguments to "yield" then this will be passed to the block. One way to use this is to pass
  # an array to layout and treat it as an enumerable.
  #
  #   <%# app/views/users/_user.html.erb %>
  #   <div class="user">
  #     Budget: $<%= user.budget %>
  #     <%= yield user %>
  #   </div>
  #
  #   <%# app/views/users/index.html.erb %>
  #   <%= render layout: @users do |user| %>
  #     Title: <%= user.title %>
  #   <% end %>
  #
  # This will render the layout for each user and yield to the block, passing the user, each time.
  #
  # You can also yield multiple times in one layout and use block arguments to differentiate the sections.
  #
  #   <%# app/views/users/_user.html.erb %>
  #   <div class="user">
  #     <%= yield user, :header %>
  #     Budget: $<%= user.budget %>
  #     <%= yield user, :footer %>
  #   </div>
  #
  #   <%# app/views/users/index.html.erb %>
  #   <%= render layout: @users do |user, section| %>
  #     <%- case section when :header -%>
  #       Title: <%= user.title %>
  #     <%- when :footer -%>
  #       Deadline: <%= user.deadline %>
  #     <%- end -%>
  #   <% end %>
  class PartialRenderer < AbstractRenderer
    include CollectionCaching

    def initialize(lookup_context, options)
      super(lookup_context)
      @options = options
      @locals  = @options[:locals] || {}
      @details = extract_details(@options)
    end

    def render(partial, context, block)
      template = find_template(partial, template_keys(partial))

      if !block && (layout = @options[:layout])
        layout = find_template(layout.to_s, template_keys(partial))
      end

      render_partial_template(context, @locals, template, layout, block)
    end

    private
      def template_keys(_)
        @locals.keys
      end

      def render_partial_template(view, locals, template, layout, block)
        instrument(:partial, identifier: template.identifier) do |payload|
          content = template.render(view, locals) do |*name|
            view._layout_for(*name, &block)
          end

          content = layout.render(view, locals) { content } if layout
          payload[:cache_hit] = view.view_renderer.cache_hits[template.virtual_path]
          build_rendered_template(content, template)
        end
      end

      def find_template(path, locals)
        prefixes = path.include?(?/) ? [] : @lookup_context.prefixes
        @lookup_context.find_template(path, prefixes, true, locals, @details)
      end

      def merge_prefix_into_object_path(prefix, object_path)
        if prefix.include?(?/) && object_path.include?(?/)
          prefixes = []
          prefix_array = File.dirname(prefix).split("/")
          object_path_array = object_path.split("/")[0..-3] # skip model dir & partial

          prefix_array.each_with_index do |dir, index|
            break if dir == object_path_array[index]
            prefixes << dir
          end

          (prefixes << object_path).join("/")
        else
          object_path
        end
      end

      IDENTIFIER_ERROR_MESSAGE = "The partial name (%s) is not a valid Ruby identifier; " \
                                 "make sure your partial name starts with underscore."

      OPTION_AS_ERROR_MESSAGE  = "The value (%s) of the option `as` is not a valid Ruby identifier; " \
                                 "make sure it starts with lowercase letter, " \
                                 "and is followed by any combination of letters, numbers and underscores."

      def raise_invalid_identifier(path)
        raise ArgumentError.new(IDENTIFIER_ERROR_MESSAGE % (path))
      end

      def raise_invalid_option_as(as)
        raise ArgumentError.new(OPTION_AS_ERROR_MESSAGE % (as))
      end
  end

  class CollectionRenderer < PartialRenderer
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
      @collection = build_collection_iterator(collection, partial, context)

      if @options[:cached] && !partial
        raise NotImplementedError, "render caching requires a template. Please specify a partial when rendering"
      end

      template = find_template(partial, template_keys(partial)) if partial

      if !block && (layout = @options[:layout])
        layout = find_template(layout.to_s, template_keys(partial))
      end

      render_collection(context, template, partial, layout)
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

      def render_collection(view, template, path, layout)
        identifier = (template && template.identifier) || path
        instrument(:collection, identifier: identifier, count: @collection.size) do |payload|
          spacer = if @options.key?(:spacer_template)
            spacer_template = find_template(@options[:spacer_template], @locals.keys)
            build_rendered_template(spacer_template.render(view, @locals), spacer_template)
          else
            RenderedTemplate::EMPTY_SPACER
          end

          collection_body = if template
            cache_collection_render(payload, view, template, @collection) do |collection|
              collection_with_template(view, template, layout, collection)
            end
          else
            collection_with_template(view, nil, layout, @collection)
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

  class ObjectRenderer < PartialRenderer
    include ObjectRendering

    def render_object_with_partial(object, partial, context, block)
      @object = object
      render(partial, context, block)
    end

    def render_object_derive_partial(object, context, block)
      path = partial_path(object, context)
      render_object_with_partial(object, path, context, block)
    end

    private

      def render_partial_template(view, locals, template, layout, block)
        as     = template.variable
        locals[as] = @object
        super(view, locals, template, layout, block)
      end
  end
end
