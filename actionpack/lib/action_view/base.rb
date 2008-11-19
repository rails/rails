module ActionView #:nodoc:
  class ActionViewError < StandardError #:nodoc:
  end

  class MissingTemplate < ActionViewError #:nodoc:
    def initialize(paths, path, template_format = nil)
      full_template_path = path.include?('.') ? path : "#{path}.erb"
      display_paths = paths.join(':')
      template_type = (path =~ /layouts/i) ? 'layout' : 'template'
      super("Missing #{template_type} #{full_template_path} in view path #{display_paths}")
    end
  end

  # Action View templates can be written in three ways. If the template file has a <tt>.erb</tt> (or <tt>.rhtml</tt>) extension then it uses a mixture of ERb
  # (included in Ruby) and HTML. If the template file has a <tt>.builder</tt> (or <tt>.rxml</tt>) extension then Jim Weirich's Builder::XmlMarkup library is used.
  # If the template file has a <tt>.rjs</tt> extension then it will use ActionView::Helpers::PrototypeHelper::JavaScriptGenerator.
  #
  # = ERb
  #
  # You trigger ERb by using embeddings such as <% %>, <% -%>, and <%= %>. The <%= %> tag set is used when you want output. Consider the
  # following loop for names:
  #
  #   <b>Names of all the people</b>
  #   <% for person in @people %>
  #     Name: <%= person.name %><br/>
  #   <% end %>
  #
  # The loop is setup in regular embedding tags <% %> and the name is written using the output embedding tag <%= %>. Note that this
  # is not just a usage suggestion. Regular output functions like print or puts won't work with ERb templates. So this would be wrong:
  #
  #   Hi, Mr. <% puts "Frodo" %>
  #
  # If you absolutely must write from within a function, you can use the TextHelper#concat.
  #
  # <%- and -%> suppress leading and trailing whitespace, including the trailing newline, and can be used interchangeably with <% and %>.
  #
  # == Using sub templates
  #
  # Using sub templates allows you to sidestep tedious replication and extract common display structures in shared templates. The
  # classic example is the use of a header and footer (even though the Action Pack-way would be to use Layouts):
  #
  #   <%= render "shared/header" %>
  #   Something really specific and terrific
  #   <%= render "shared/footer" %>
  #
  # As you see, we use the output embeddings for the render methods. The render call itself will just return a string holding the
  # result of the rendering. The output embedding writes it to the current template.
  #
  # But you don't have to restrict yourself to static includes. Templates can share variables amongst themselves by using instance
  # variables defined using the regular embedding tags. Like this:
  #
  #   <% @page_title = "A Wonderful Hello" %>
  #   <%= render "shared/header" %>
  #
  # Now the header can pick up on the <tt>@page_title</tt> variable and use it for outputting a title tag:
  #
  #   <title><%= @page_title %></title>
  #
  # == Passing local variables to sub templates
  #
  # You can pass local variables to sub templates by using a hash with the variable names as keys and the objects as values:
  #
  #   <%= render "shared/header", { :headline => "Welcome", :person => person } %>
  #
  # These can now be accessed in <tt>shared/header</tt> with:
  #
  #   Headline: <%= headline %>
  #   First name: <%= person.first_name %>
  #
  # If you need to find out whether a certain local variable has been assigned a value in a particular render call,
  # you need to use the following pattern:
  #
  #   <% if local_assigns.has_key? :headline %>
  #     Headline: <%= headline %>
  #   <% end %>
  #
  # Testing using <tt>defined? headline</tt> will not work. This is an implementation restriction.
  #
  # == Template caching
  #
  # By default, Rails will compile each template to a method in order to render it. When you alter a template, Rails will
  # check the file's modification time and recompile it.
  #
  # == Builder
  #
  # Builder templates are a more programmatic alternative to ERb. They are especially useful for generating XML content. An XmlMarkup object
  # named +xml+ is automatically made available to templates with a <tt>.builder</tt> extension.
  #
  # Here are some basic examples:
  #
  #   xml.em("emphasized")                              # => <em>emphasized</em>
  #   xml.em { xml.b("emph & bold") }                   # => <em><b>emph &amp; bold</b></em>
  #   xml.a("A Link", "href"=>"http://onestepback.org") # => <a href="http://onestepback.org">A Link</a>
  #   xml.target("name"=>"compile", "option"=>"fast")   # => <target option="fast" name="compile"\>
  #                                                     # NOTE: order of attributes is not specified.
  #
  # Any method with a block will be treated as an XML markup tag with nested markup in the block. For example, the following:
  #
  #   xml.div {
  #     xml.h1(@person.name)
  #     xml.p(@person.bio)
  #   }
  #
  # would produce something like:
  #
  #   <div>
  #     <h1>David Heinemeier Hansson</h1>
  #     <p>A product of Danish Design during the Winter of '79...</p>
  #   </div>
  #
  # A full-length RSS example actually used on Basecamp:
  #
  #   xml.rss("version" => "2.0", "xmlns:dc" => "http://purl.org/dc/elements/1.1/") do
  #     xml.channel do
  #       xml.title(@feed_title)
  #       xml.link(@url)
  #       xml.description "Basecamp: Recent items"
  #       xml.language "en-us"
  #       xml.ttl "40"
  #
  #       for item in @recent_items
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
  # More builder documentation can be found at http://builder.rubyforge.org.
  #
  # == JavaScriptGenerator
  #
  # JavaScriptGenerator templates end in <tt>.rjs</tt>. Unlike conventional templates which are used to
  # render the results of an action, these templates generate instructions on how to modify an already rendered page. This makes it easy to
  # modify multiple elements on your page in one declarative Ajax response. Actions with these templates are called in the background with Ajax
  # and make updates to the page where the request originated from.
  #
  # An instance of the JavaScriptGenerator object named +page+ is automatically made available to your template, which is implicitly wrapped in an ActionView::Helpers::PrototypeHelper#update_page block.
  #
  # When an <tt>.rjs</tt> action is called with +link_to_remote+, the generated JavaScript is automatically evaluated.  Example:
  #
  #   link_to_remote :url => {:action => 'delete'}
  #
  # The subsequently rendered <tt>delete.rjs</tt> might look like:
  #
  #   page.replace_html  'sidebar', :partial => 'sidebar'
  #   page.remove        "person-#{@person.id}"
  #   page.visual_effect :highlight, 'user-list'
  #
  # This refreshes the sidebar, removes a person element and highlights the user list.
  #
  # See the ActionView::Helpers::PrototypeHelper::GeneratorMethods documentation for more details.
  class Base
    include ERB::Util
    extend ActiveSupport::Memoizable

    attr_accessor :base_path, :assigns, :template_extension
    attr_accessor :controller

    attr_writer :template_format

    attr_accessor :output_buffer

    class << self
      delegate :erb_trim_mode=, :to => 'ActionView::TemplateHandlers::ERB'
      delegate :logger, :to => 'ActionController::Base'
    end

    # Templates that are exempt from layouts
    @@exempt_from_layout = Set.new([/\.rjs$/])

    # Don't render layouts for templates with the given extensions.
    def self.exempt_from_layout(*extensions)
      regexps = extensions.collect do |extension|
        extension.is_a?(Regexp) ? extension : /\.#{Regexp.escape(extension.to_s)}$/
      end
      @@exempt_from_layout.merge(regexps)
    end

    # Specify whether RJS responses should be wrapped in a try/catch block
    # that alert()s the caught exception (and then re-raises it).
    @@debug_rjs = false
    cattr_accessor :debug_rjs

    # A warning will be displayed whenever an action results in a cache miss on your view paths.
    @@warn_cache_misses = false
    cattr_accessor :warn_cache_misses

    attr_internal :request

    delegate :request_forgery_protection_token, :template, :params, :session, :cookies, :response, :headers,
             :flash, :logger, :action_name, :controller_name, :to => :controller

    module CompiledTemplates #:nodoc:
      # holds compiled template code
    end
    include CompiledTemplates

    def self.process_view_paths(value)
      ActionView::PathSet.new(Array(value))
    end

    attr_reader :helpers

    class ProxyModule < Module
      def initialize(receiver)
        @receiver = receiver
      end

      def include(*args)
        super(*args)
        @receiver.extend(*args)
      end
    end

    def initialize(view_paths = [], assigns_for_first_render = {}, controller = nil)#:nodoc:
      @assigns = assigns_for_first_render
      @assigns_added = nil
      @_render_stack = []
      @controller = controller
      @helpers = ProxyModule.new(self)
      self.view_paths = view_paths
    end

    attr_reader :view_paths

    def view_paths=(paths)
      @view_paths = self.class.process_view_paths(paths)
    end

    # Renders the template present at <tt>template_path</tt> (relative to the view_paths array).
    # The hash in <tt>local_assigns</tt> is made available as local variables.
    def render(options = {}, local_assigns = {}, &block) #:nodoc:
      local_assigns ||= {}

      if options.is_a?(String)
        ActiveSupport::Deprecation.warn(
          "Calling render with a string will render a partial from Rails 2.3. " +
          "Change this call to render(:file => '#{options}', :locals => locals_hash)."
        )

        render(:file => options, :locals => local_assigns)
      elsif options == :update
        update_page(&block)
      elsif options.is_a?(Hash)
        options = options.reverse_merge(:locals => {})
        if options[:layout]
          _render_with_layout(options, local_assigns, &block)
        elsif options[:file]
          _pick_template(options[:file]).render_template(self, options[:locals])
        elsif options[:partial]
          render_partial(options)
        elsif options[:inline]
          InlineTemplate.new(options[:inline], options[:type]).render(self, options[:locals])
        elsif options[:text]
          options[:text]
        end
      end
    end

    # The format to be used when choosing between multiple templates with
    # the same name but differing formats.  See +Request#template_format+
    # for more details.
    def template_format
      if defined? @template_format
        @template_format
      elsif controller && controller.respond_to?(:request)
        @template_format = controller.request.template_format
      else
        @template_format = :html
      end
    end

    # Access the current template being rendered.
    # Returns a ActionView::Template object.
    def template
      @_render_stack.last
    end

    private
      # Evaluates the local assigns and controller ivars, pushes them to the view.
      def _evaluate_assigns_and_ivars #:nodoc:
        unless @assigns_added
          @assigns.each { |key, value| instance_variable_set("@#{key}", value) }
          _copy_ivars_from_controller
          @assigns_added = true
        end
      end

      def _copy_ivars_from_controller #:nodoc:
        if @controller
          variables = @controller.instance_variable_names
          variables -= @controller.protected_instance_variables if @controller.respond_to?(:protected_instance_variables)
          variables.each { |name| instance_variable_set(name, @controller.instance_variable_get(name)) }
        end
      end

      def _set_controller_content_type(content_type) #:nodoc:
        if controller.respond_to?(:response)
          controller.response.content_type ||= content_type
        end
      end

      def _pick_template(template_path)
        return template_path if template_path.respond_to?(:render)

        path = template_path.sub(/^\//, '')
        if m = path.match(/(.*)\.(\w+)$/)
          template_file_name, template_file_extension = m[1], m[2]
        else
          template_file_name = path
        end

        # OPTIMIZE: Checks to lookup template in view path
        if template = self.view_paths["#{template_file_name}.#{template_format}"]
          template
        elsif template = self.view_paths[template_file_name]
          template
        elsif (first_render = @_render_stack.first) && first_render.respond_to?(:format_and_extension) &&
            (template = self.view_paths["#{template_file_name}.#{first_render.format_and_extension}"])
          template
        elsif template_format == :js && template = self.view_paths["#{template_file_name}.html"]
          @template_format = :html
          template
        else
          template = Template.new(template_path, view_paths)

          if self.class.warn_cache_misses && logger
            logger.debug "[PERFORMANCE] Rendering a template that was " +
              "not found in view path. Templates outside the view path are " +
              "not cached and result in expensive disk operations. Move this " +
              "file into #{view_paths.join(':')} or add the folder to your " +
              "view path list"
          end

          template
        end
      end
      memoize :_pick_template

      def _exempt_from_layout?(template_path) #:nodoc:
        template = _pick_template(template_path).to_s
        @@exempt_from_layout.any? { |ext| template =~ ext }
      rescue ActionView::MissingTemplate
        return false
      end

      def _render_with_layout(options, local_assigns, &block) #:nodoc:
        partial_layout = options.delete(:layout)

        if block_given?
          begin
            @_proc_for_layout = block
            concat(render(options.merge(:partial => partial_layout)))
          ensure
            @_proc_for_layout = nil
          end
        else
          begin
            original_content_for_layout = @content_for_layout if defined?(@content_for_layout)
            @content_for_layout = render(options)

            if (options[:inline] || options[:file] || options[:text])
              @cached_content_for_layout = @content_for_layout
              render(:file => partial_layout, :locals => local_assigns)
            else
              render(options.merge(:partial => partial_layout))
            end
          ensure
            @content_for_layout = original_content_for_layout
          end
        end
      end
  end
end
