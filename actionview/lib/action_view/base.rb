# frozen_string_literal: true

require "active_support/core_ext/module/attr_internal"
require "active_support/core_ext/module/attribute_accessors"
require "active_support/ordered_options"
require "action_view/log_subscriber"
require "action_view/helpers"
require "action_view/context"
require "action_view/template"
require "action_view/lookup_context"

module ActionView # :nodoc:
  # = Action View \Base
  #
  # Action View templates can be written in several ways.
  # If the template file has a <tt>.erb</tt> extension, then it uses the erubi[https://rubygems.org/gems/erubi]
  # template system which can embed Ruby into an HTML document.
  # If the template file has a <tt>.builder</tt> extension, then Jim Weirich's Builder::XmlMarkup library is used.
  #
  # == ERB
  #
  # You trigger ERB by using embeddings such as <tt><% %></tt>, <tt><% -%></tt>, and <tt><%= %></tt>. The <tt><%= %></tt> tag set is used when you want output. Consider the
  # following loop for names:
  #
  #   <b>Names of all the people</b>
  #   <% @people.each do |person| %>
  #     Name: <%= person.name %><br/>
  #   <% end %>
  #
  # The loop is set up in regular embedding tags <tt><% %></tt>, and the name is written using the output embedding tag <tt><%= %></tt>. Note that this
  # is not just a usage suggestion. Regular output functions like print or puts won't work with ERB templates. So this would be wrong:
  #
  #   <%# WRONG %>
  #   Hi, Mr. <% puts "Frodo" %>
  #
  # If you absolutely must write from within a function use +concat+.
  #
  # When on a line that only contains whitespaces except for the tag, <tt><% %></tt> suppresses leading and trailing whitespace,
  # including the trailing newline. <tt><% %></tt> and <tt><%- -%></tt> are the same.
  # Note however that <tt><%= %></tt> and <tt><%= -%></tt> are different: only the latter removes trailing whitespaces.
  #
  # === Using sub templates
  #
  # Using sub templates allows you to sidestep tedious replication and extract common display structures in shared templates. The
  # classic example is the use of a header and footer (even though the Action Pack-way would be to use Layouts):
  #
  #   <%= render "application/header" %>
  #   Something really specific and terrific
  #   <%= render "application/footer" %>
  #
  # As you see, we use the output embeddings for the render methods. The render call itself will just return a string holding the
  # result of the rendering. The output embedding writes it to the current template.
  #
  # But you don't have to restrict yourself to static includes. Templates can share variables amongst themselves by using instance
  # variables defined using the regular embedding tags. Like this:
  #
  #   <% @page_title = "A Wonderful Hello" %>
  #   <%= render "application/header" %>
  #
  # Now the header can pick up on the <tt>@page_title</tt> variable and use it for outputting a title tag:
  #
  #   <title><%= @page_title %></title>
  #
  # === Passing local variables to sub templates
  #
  # You can pass local variables to sub templates by using a hash with the variable names as keys and the objects as values:
  #
  #   <%= render "application/header", { headline: "Welcome", person: person } %>
  #
  # These can now be accessed in <tt>application/header</tt> with:
  #
  #   Headline: <%= headline %>
  #   First name: <%= person.first_name %>
  #
  # The local variables passed to sub templates can be accessed as a hash using the <tt>local_assigns</tt> hash. This lets you access the
  # variables as:
  #
  #   Headline: <%= local_assigns[:headline] %>
  #
  # This is useful in cases where you aren't sure if the local variable has been assigned. Alternatively, you could also use
  # <tt>defined? headline</tt> to first check if the variable has been assigned before using it.
  #
  # By default, templates will accept any <tt>locals</tt> as keyword arguments. To restrict what <tt>locals</tt> a template accepts, add a <tt>locals:</tt> magic comment:
  #
  #   <%# locals: (headline:) %>
  #
  #   Headline: <%= headline %>
  #
  # In cases where the local variables are optional, declare the keyword argument with a default value:
  #
  #   <%# locals: (headline: nil) %>
  #
  #   <% unless headline.nil? %>
  #   Headline: <%= headline %>
  #   <% end %>
  #
  # Read more about strict locals in {Action View Overview}[https://guides.rubyonrails.org/action_view_overview.html#strict-locals]
  # in the guides.
  #
  # === Template caching
  #
  # By default, \Rails will compile each template to a method in order to render it. When you alter a template,
  # \Rails will check the file's modification time and recompile it in development mode.
  #
  # == Builder
  #
  # Builder templates are a more programmatic alternative to ERB. They are especially useful for generating XML content. An XmlMarkup object
  # named +xml+ is automatically made available to templates with a <tt>.builder</tt> extension.
  #
  # Here are some basic examples:
  #
  #   xml.em("emphasized")                                 # => <em>emphasized</em>
  #   xml.em { xml.b("emph & bold") }                      # => <em><b>emph &amp; bold</b></em>
  #   xml.a("A Link", "href" => "http://onestepback.org")  # => <a href="http://onestepback.org">A Link</a>
  #   xml.target("name" => "compile", "option" => "fast")  # => <target option="fast" name="compile"\>
  #                                                        # NOTE: order of attributes is not specified.
  #
  # Any method with a block will be treated as an XML markup tag with nested markup in the block. For example, the following:
  #
  #   xml.div do
  #     xml.h1(@person.name)
  #     xml.p(@person.bio)
  #   end
  #
  # would produce something like:
  #
  #   <div>
  #     <h1>David Heinemeier Hansson</h1>
  #     <p>A product of Danish Design during the Winter of '79...</p>
  #   </div>
  #
  # Here is a full-length RSS example actually used on Basecamp:
  #
  #   xml.rss("version" => "2.0", "xmlns:dc" => "http://purl.org/dc/elements/1.1/") do
  #     xml.channel do
  #       xml.title(@feed_title)
  #       xml.link(@url)
  #       xml.description "Basecamp: Recent items"
  #       xml.language "en-us"
  #       xml.ttl "40"
  #
  #       @recent_items.each do |item|
  #         xml.item do
  #           xml.title(item_title(item))
  #           xml.description(item_description(item)) if item_description(item)
  #           xml.pubDate(item_pubDate(item))
  #           xml.guid(@person.firm.account.url + @recent_items.url(item))
  #           xml.link(@person.firm.account.url + @recent_items.url(item))
  #
  #           xml.tag!("dc:creator", item.author_name) if item_has_creator?(item)
  #         end
  #       end
  #     end
  #   end
  #
  # For more information on Builder please consult the {source code}[https://github.com/rails/builder].
  class Base
    include Helpers, ::ERB::Util, Context

    # Specify the proc used to decorate input tags that refer to attributes with errors.
    cattr_accessor :field_error_proc, default: Proc.new { |html_tag, instance| content_tag :div, html_tag, class: "field_with_errors" }

    # How to complete the streaming when an exception occurs.
    # This is our best guess: first try to close the attribute, then the tag.
    cattr_accessor :streaming_completion_on_exception, default: %("><script>window.location = "/500.html"</script></html>)

    # Specify whether rendering within namespaced controllers should prefix
    # the partial paths for ActiveModel objects with the namespace.
    # (e.g., an Admin::PostsController would render @post using /admin/posts/_post.erb)
    class_attribute :prefix_partial_path_with_controller_namespace, default: true

    # Specify default_formats that can be rendered.
    cattr_accessor :default_formats

    # Specify whether submit_tag should automatically disable on click
    cattr_accessor :automatically_disable_submit_tag, default: true

    # Annotate rendered view with file names
    cattr_accessor :annotate_rendered_view_with_filenames, default: false

    class_attribute :_routes
    class_attribute :logger

    class << self
      delegate :erb_trim_mode=, to: "ActionView::Template::Handlers::ERB"

      def cache_template_loading
        ActionView::Resolver.caching?
      end

      def cache_template_loading=(value)
        ActionView::Resolver.caching = value
      end

      def xss_safe? # :nodoc:
        true
      end

      def with_empty_template_cache # :nodoc:
        subclass = Class.new(self) {
          # We can't implement these as self.class because subclasses will
          # share the same template cache as superclasses, so "changed?" won't work
          # correctly.
          define_method(:compiled_method_container)           { subclass }
          define_singleton_method(:compiled_method_container) { subclass }

          def inspect
            "#<ActionView::Base:#{'%#016x' % (object_id << 1)}>"
          end
        }
      end

      def changed?(other) # :nodoc:
        compiled_method_container != other.compiled_method_container
      end
    end

    attr_reader :view_renderer, :lookup_context
    attr_internal :config, :assigns

    delegate :formats, :formats=, :locale, :locale=, :view_paths, :view_paths=, to: :lookup_context

    def assign(new_assigns) # :nodoc:
      @_assigns = new_assigns
      new_assigns.each { |key, value| instance_variable_set("@#{key}", value) }
    end

    # :stopdoc:

    def self.empty
      with_view_paths([])
    end

    def self.with_view_paths(view_paths, assigns = {}, controller = nil)
      with_context ActionView::LookupContext.new(view_paths), assigns, controller
    end

    def self.with_context(context, assigns = {}, controller = nil)
      new context, assigns, controller
    end

    # :startdoc:

    def initialize(lookup_context, assigns, controller) # :nodoc:
      @_config = ActiveSupport::InheritableOptions.new

      @lookup_context = lookup_context

      @view_renderer = ActionView::Renderer.new @lookup_context
      @current_template = nil

      assign_controller(controller)
      _prepare_context

      super()

      # Assigns must be called last to minimize the number of shapes
      assign(assigns)
    end

    def _run(method, template, locals, buffer, add_to_stack: true, has_strict_locals: false, &block)
      _old_output_buffer, _old_virtual_path, _old_template = @output_buffer, @virtual_path, @current_template
      @current_template = template if add_to_stack
      @output_buffer = buffer

      if has_strict_locals
        begin
          public_send(method, locals, buffer, **locals, &block)
        rescue ArgumentError => argument_error
          raise(
            ArgumentError,
            argument_error.
              message.
                gsub("unknown keyword:", "unknown local:").
                gsub("missing keyword:", "missing local:").
                gsub("no keywords accepted", "no locals accepted").
                concat(" for #{@current_template.short_identifier}")
          )
        end
      else
        public_send(method, locals, buffer, &block)
      end
    ensure
      @output_buffer, @virtual_path, @current_template = _old_output_buffer, _old_virtual_path, _old_template
    end

    def compiled_method_container
      raise NotImplementedError, <<~msg.squish
        Subclasses of ActionView::Base must implement `compiled_method_container`
        or use the class method `with_empty_template_cache` for constructing
        an ActionView::Base subclass that has an empty cache.
      msg
    end

    def in_rendering_context(options)
      old_view_renderer  = @view_renderer
      old_lookup_context = @lookup_context

      if !lookup_context.html_fallback_for_js && options[:formats]
        formats = Array(options[:formats])
        if formats == [:js]
          formats << :html
        end
        @lookup_context = lookup_context.with_prepended_formats(formats)
        @view_renderer = ActionView::Renderer.new @lookup_context
      end

      yield @view_renderer
    ensure
      @view_renderer = old_view_renderer
      @lookup_context = old_lookup_context
    end

    ActiveSupport.run_load_hooks(:action_view, self)
  end
end
