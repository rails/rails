require 'active_support/core_ext/module/attr_internal'
require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/array/wrap'
require 'active_support/ordered_options'
require 'action_view/log_subscriber'

module ActionView #:nodoc:
  class NonConcattingString < ActiveSupport::SafeBuffer
  end

  # = Action View Base
  #
  # Action View templates can be written in three ways. If the template file has a <tt>.erb</tt> (or <tt>.rhtml</tt>) extension then it uses a mixture of ERb
  # (included in Ruby) and HTML. If the template file has a <tt>.builder</tt> (or <tt>.rxml</tt>) extension then Jim Weirich's Builder::XmlMarkup library is used.
  # If the template file has a <tt>.rjs</tt> extension then it will use ActionView::Helpers::PrototypeHelper::JavaScriptGenerator.
  #
  # == ERb
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
  #   <%# WRONG %>
  #   Hi, Mr. <% puts "Frodo" %>
  #
  # If you absolutely must write from within a function use +concat+.
  #
  # <%- and -%> suppress leading and trailing whitespace, including the trailing newline, and can be used interchangeably with <% and %>.
  #
  # === Using sub templates
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
  # === Passing local variables to sub templates
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
  # === Template caching
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
  # See the ActionView::Helpers::PrototypeHelper::JavaScriptGenerator::GeneratorMethods documentation for more details.
  class Base
    module Subclasses
    end

    include Helpers, Rendering, Partials, Layouts, ::ERB::Util, Context

    # Specify whether RJS responses should be wrapped in a try/catch block
    # that alert()s the caught exception (and then re-raises it).
    cattr_accessor :debug_rjs
    @@debug_rjs = false

    # Specify the proc used to decorate input tags that refer to attributes with errors.
    cattr_accessor :field_error_proc
    @@field_error_proc = Proc.new{ |html_tag, instance| "<div class=\"field_with_errors\">#{html_tag}</div>".html_safe }

    class_attribute :helpers
    class_attribute :_routes

    class << self
      delegate :erb_trim_mode=, :to => 'ActionView::Template::Handlers::ERB'
      delegate :logger, :to => 'ActionController::Base', :allow_nil => true
    end

    attr_accessor :base_path, :assigns, :template_extension, :lookup_context
    attr_internal :captures, :request, :controller, :template, :config

    delegate :find_template, :template_exists?, :formats, :formats=, :locale, :locale=,
             :view_paths, :view_paths=, :with_fallbacks, :update_details, :with_layout_format, :to => :lookup_context

    delegate :request_forgery_protection_token, :template, :params, :session, :cookies, :response, :headers,
             :flash, :action_name, :controller_name, :to => :controller

    delegate :logger, :to => :controller, :allow_nil => true

    # TODO: HACK FOR RJS
    def view_context
      self
    end

    def self.xss_safe? #:nodoc:
      true
    end

    def self.process_view_paths(value)
      value.is_a?(PathSet) ?
        value.dup : ActionView::PathSet.new(Array.wrap(value))
    end

    def assign(new_assigns) # :nodoc:
      self.assigns = new_assigns.each { |key, value| instance_variable_set("@#{key}", value) }
    end

    def initialize(lookup_context = nil, assigns_for_first_render = {}, controller = nil, formats = nil) #:nodoc:
      assign(assigns_for_first_render)
      self.helpers = self.class.helpers || Module.new

      if @_controller = controller
        @_request = controller.request if controller.respond_to?(:request)
      end

      config = controller && controller.respond_to?(:config) ? controller.config : {}
      @_config = ActiveSupport::InheritableOptions.new(config)

      @_content_for  = Hash.new { |h,k| h[k] = ActiveSupport::SafeBuffer.new }
      @_virtual_path = nil
      @output_buffer = nil

      @lookup_context = lookup_context.is_a?(ActionView::LookupContext) ?
        lookup_context : ActionView::LookupContext.new(lookup_context)
      @lookup_context.formats = formats if formats
      @controller = ActiveSupport::Deprecation::DeprecatedInstanceVariableProxy.new(self, :controller)
    end

    def controller_path
      @controller_path ||= controller && controller.controller_path
    end

    ActiveSupport.run_load_hooks(:action_view, self)
  end
end
