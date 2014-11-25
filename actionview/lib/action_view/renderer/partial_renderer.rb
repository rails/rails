require 'thread_safe'

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
  # This would first render "advertiser/_account.html.erb" with @buyer passed in as the local variable +account+, then
  # render "advertiser/_ad.html.erb" and pass the local variable +ad+ to the template for display.
  #
  # == The :as and :object options
  #
  # By default <tt>ActionView::PartialRenderer</tt> doesn't have any local variables.
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
  # == Rendering a collection of partials
  #
  # The example of partial use describes a familiar pattern where a template needs to iterate over an array and
  # render a sub template for each of the elements. This pattern has been implemented as a single method that
  # accepts an array and renders a partial by the same name as the elements contained within. So the three-lined
  # example in "Using partials" can be rewritten with a single line:
  #
  #   <%= render partial: "ad", collection: @advertisements %>
  #
  # This will render "advertiser/_ad.html.erb" and pass the local variable +ad+ to the template for display. An
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
  # If the given <tt>:collection</tt> is nil or empty, <tt>render</tt> will return nil. This will allow you
  # to specify a text which will displayed instead by using this form:
  #
  #   <%= render(partial: "ad", collection: @advertisements) || "There's no ad to be displayed" %>
  #
  # NOTE: Due to backwards compatibility concerns, the collection can't be one of hashes. Normally you'd also
  # just keep domain objects, like Active Records, in there.
  #
  # == Rendering shared partials
  #
  # Two controllers can share a set of partials and render them like this:
  #
  #   <%= render partial: "advertisement/ad", locals: { ad: @advertisement } %>
  #
  # This will render the partial "advertisement/_ad.html.erb" regardless of which controller this is being called from.
  #
  # == Rendering objects that respond to `to_partial_path`
  #
  # Instead of explicitly naming the location of a partial, you can also let PartialRenderer do the work
  # and pick the proper path by checking `to_partial_path` method.
  #
  #  # @account.to_partial_path returns 'accounts/account', so it can be used to replace:
  #  # <%= render partial: "accounts/account", locals: { account: @account} %>
  #  <%= render partial: @account %>
  #
  #  # @posts is an array of Post instances, so every post record returns 'posts/post' on `to_partial_path`,
  #  # that's why we can replace:
  #  # <%= render partial: "posts/post", collection: @posts %>
  #  <%= render partial: @posts %>
  #
  # == Rendering the default case
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
  #  # @posts is an array of Post instances, so every post record returns 'posts/post' on `to_partial_path`,
  #  # that's why we can replace:
  #  # <%= render partial: "posts/post", collection: @posts %>
  #  <%= render @posts %>
  #
  # == Rendering partials with layouts
  #
  # Partials can have their own layouts applied to them. These layouts are different than the ones that are
  # specified globally for the entire action, but they work in a similar fashion. Imagine a list with two types
  # of users:
  #
  #   <%# app/views/users/index.html.erb &>
  #   Here's the administrator:
  #   <%= render partial: "user", layout: "administrator", locals: { user: administrator } %>
  #
  #   Here's the editor:
  #   <%= render partial: "user", layout: "editor", locals: { user: editor } %>
  #
  #   <%# app/views/users/_user.html.erb &>
  #   Name: <%= user.name %>
  #
  #   <%# app/views/users/_administrator.html.erb &>
  #   <div id="administrator">
  #     Budget: $<%= user.budget %>
  #     <%= yield %>
  #   </div>
  #
  #   <%# app/views/users/_editor.html.erb &>
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
  #   <%# app/views/users/_chief.html.erb &>
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
  #   <%# app/views/users/_user.html.erb &>
  #   <div class="user">
  #     Budget: $<%= user.budget %>
  #     <%= yield user %>
  #   </div>
  #
  #   <%# app/views/users/index.html.erb &>
  #   <%= render layout: @users do |user| %>
  #     Title: <%= user.title %>
  #   <% end %>
  #
  # This will render the layout for each user and yield to the block, passing the user, each time.
  #
  # You can also yield multiple times in one layout and use block arguments to differentiate the sections.
  #
  #   <%# app/views/users/_user.html.erb &>
  #   <div class="user">
  #     <%= yield user, :header %>
  #     Budget: $<%= user.budget %>
  #     <%= yield user, :footer %>
  #   </div>
  #
  #   <%# app/views/users/index.html.erb &>
  #   <%= render layout: @users do |user, section| %>
  #     <%- case section when :header -%>
  #       Title: <%= user.title %>
  #     <%- when :footer -%>
  #       Deadline: <%= user.deadline %>
  #     <%- end -%>
  #   <% end %>
  class PartialRenderer < AbstractRenderer
    PREFIXED_PARTIAL_NAMES = ThreadSafe::Cache.new do |h, k|
      h[k] = ThreadSafe::Cache.new
    end

    def initialize(*)
      super
      @context_prefix = @lookup_context.prefixes.first
    end

    def render(context, options, block)
      setup(context, options, block)
      identifier = (@template = find_partial) ? @template.identifier : @path

      @lookup_context.rendered_format ||= begin
        if @template && @template.formats.present?
          @template.formats.first
        else
          formats.first
        end
      end

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

    private

    def render_collection
      return nil if @collection.blank?

      if @options.key?(:spacer_template)
        spacer = find_template(@options[:spacer_template], @locals.keys).render(@view, @locals)
      end

      result = @template ? collection_with_template : collection_without_template
      result.join(spacer).html_safe
    end

    def render_partial
      view, locals, block = @view, @locals, @block
      object, as = @object, @variable

      if !block && (layout = @options[:layout])
        layout = find_template(layout.to_s, @template_keys)
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

    # Sets up instance variables needed for rendering a partial. This method
    # finds the options and details and extracts them. The method also contains
    # logic that handles the type of object passed in as the partial.
    #
    # If +options[:partial]+ is a string, then the +@path+ instance variable is
    # set to that string. Otherwise, the +options[:partial]+ object must
    # respond to +to_partial_path+ in order to setup the path.
    def setup(context, options, block)
      @view   = context
      @options = options
      @block   = block

      @locals  = options[:locals] || {}
      @details = extract_details(options)

      prepend_formats(options[:formats])

      partial = options[:partial]

      if String === partial
        @has_object = options.key?(:object)
        @object     = options[:object]
        @collection = collection_from_options
        @path       = partial
      else
        @has_object = true
        @object = partial
        @collection = collection_from_object || collection_from_options

        if @collection
          paths = @collection_data = @collection.map { |o| partial_path(o) }
          @path = paths.uniq.one? ? paths.first : nil
        else
          @path = partial_path
        end
      end

      if as = options[:as]
        raise_invalid_identifier(as) unless as.to_s =~ /\A[a-z_]\w*\z/
        as = as.to_sym
      end

      if @path
        @variable, @variable_counter, @variable_iteration = retrieve_variable(@path, as)
        @template_keys = retrieve_template_keys
      else
        paths.map! { |path| retrieve_variable(path, as).unshift(path) }
      end

      self
    end

    def collection_from_options
      if @options.key?(:collection)
        collection = @options[:collection]
        collection.respond_to?(:to_ary) ? collection.to_ary : []
      end
    end

    def collection_from_object
      @object.to_ary if @object.respond_to?(:to_ary)
    end

    def find_partial
      find_template(@path, @template_keys) if @path
    end

    def find_template(path, locals)
      prefixes = path.include?(?/) ? [] : @lookup_context.prefixes
      @lookup_context.find_template(path, prefixes, true, locals, @details)
    end

    def collection_with_template
      view, locals, template = @view, @locals, @template
      as, counter, iteration = @variable, @variable_counter, @variable_iteration

      if layout = @options[:layout]
        layout = find_template(layout, @template_keys)
      end

      partial_iteration = PartialIteration.new(@collection.size)
      locals[iteration] = partial_iteration

      @collection.map do |object|
        locals[as]        = object
        locals[counter]   = partial_iteration.index

        content = template.render(view, locals)
        content = layout.render(view, locals) { content } if layout
        partial_iteration.iterate!
        content
      end
    end

    def collection_without_template
      view, locals, collection_data = @view, @locals, @collection_data
      cache = {}
      keys  = @locals.keys

      partial_iteration = PartialIteration.new(@collection.size)

      @collection.map do |object|
        index = partial_iteration.index
        path, as, counter, iteration = collection_data[index]

        locals[as]        = object
        locals[counter]   = index
        locals[iteration] = partial_iteration

        template = (cache[path] ||= find_template(path, keys + [as, counter]))
        content = template.render(view, locals)
        partial_iteration.iterate!
        content
      end
    end

    # Obtains the path to where the object's partial is located. If the object
    # responds to +to_partial_path+, then +to_partial_path+ will be called and
    # will provide the path. If the object does not respond to +to_partial_path+,
    # then an +ArgumentError+ is raised.
    #
    # If +prefix_partial_path_with_controller_namespace+ is true, then this
    # method will prefix the partial paths with a namespace.
    def partial_path(object = @object)
      object = object.to_model if object.respond_to?(:to_model)

      path = if object.respond_to?(:to_partial_path)
        object.to_partial_path
      else
        raise ArgumentError.new("'#{object.inspect}' is not an ActiveModel-compatible object. It must implement :to_partial_path.")
      end

      if @view.prefix_partial_path_with_controller_namespace
        prefixed_partial_names[path] ||= merge_prefix_into_object_path(@context_prefix, path.dup)
      else
        path
      end
    end

    def prefixed_partial_names
      @prefixed_partial_names ||= PREFIXED_PARTIAL_NAMES[@context_prefix]
    end

    def merge_prefix_into_object_path(prefix, object_path)
      if prefix.include?(?/) && object_path.include?(?/)
        prefixes = []
        prefix_array = File.dirname(prefix).split('/')
        object_path_array = object_path.split('/')[0..-3] # skip model dir & partial

        prefix_array.each_with_index do |dir, index|
          break if dir == object_path_array[index]
          prefixes << dir
        end

        (prefixes << object_path).join("/")
      else
        object_path
      end
    end

    def retrieve_template_keys
      keys = @locals.keys
      keys << @variable if @has_object || @collection
      if @collection
        keys << @variable_counter
        keys << @variable_iteration
      end
      keys
    end

    def retrieve_variable(path, as)
      variable = as || begin
        base = path[-1] == "/" ? "" : File.basename(path)
        raise_invalid_identifier(path) unless base =~ /\A_?([a-z]\w*)(\.\w+)*\z/
        $1.to_sym
      end
      if @collection
        variable_counter = :"#{variable}_counter"
        variable_iteration = :"#{variable}_iteration"
      end
      [variable, variable_counter, variable_iteration]
    end

    IDENTIFIER_ERROR_MESSAGE = "The partial name (%s) is not a valid Ruby identifier; " +
                               "make sure your partial name starts with a lowercase letter or underscore, " +
                               "and is followed by any combination of letters, numbers and underscores."

    def raise_invalid_identifier(path)
      raise ArgumentError.new(IDENTIFIER_ERROR_MESSAGE % (path))
    end
  end
end
