require 'erb'

module ActionView #:nodoc:
  class ActionViewError < StandardError #:nodoc:
  end

  # Action View templates can be written in two ways. If the template file has a +.rhtml+ extension then it uses a mixture of ERb 
  # (included in Ruby) and HTML. If the template file has a +.rxml+ extension then Jim Weirich's Builder::XmlMarkup library is used.  
  # 
  # = ERb
  # 
  # You trigger ERb by using embeddings such as <% %> and <%= %>. The difference is whether you want output or not. Consider the 
  # following loop for names:
  #
  #   <b>Names of all the people</b>
  #   <% for person in @people %>
  #     Name: <%= person.name %><br/>
  #   <% end %>
  #
  # The loop is setup in regular embedding tags (<% %>) and the name is written using the output embedding tag (<%= %>). Note that this
  # is not just a usage suggestion. Regular output functions like print or puts won't work with ERb templates. So this would be wrong:
  #
  #   Hi, Mr. <% puts "Frodo" %>
  #
  # (If you absolutely must write from within a function, you can use the TextHelper#concat)
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
  # variables defined in using the regular embedding tags. Like this:
  #
  #   <% @page_title = "A Wonderful Hello" %>
  #   <%= render "shared/header" %>
  #
  # Now the header can pick up on the @page_title variable and use it for outputting a title tag:
  #
  #   <title><%= @page_title %></title>
  #
  # == Passing local variables to sub templates
  # 
  # You can pass local variables to sub templates by using a hash with the variable names as keys and the objects as values:
  #
  #   <%= render "shared/header", { "headline" => "Welcome", "person" => person } %>
  #
  # These can now be accessed in shared/header with:
  #
  #   Headline: <%= headline %>
  #   First name: <%= person.first_name %>
  #
  # == Template caching
  #
  # The parsing of ERb templates are cached by default, but the reading of them are not. This means that the application by default
  # will reflect changes to the templates immediatly. If you'd like to sacrifice that immediacy for the speed gain given by also
  # caching the loading of templates (reading from the file systen), you can turn that on with 
  # <tt>ActionView::Base.cache_template_loading = true</tt>.
  #
  # == Builder
  #
  # Builder templates are a more programatic alternative to ERb. They are especially useful for generating XML content. An +XmlMarkup+ object 
  # named +xml+ is automatically made available to templates with a +.rxml+ extension. 
  #
  # Here are some basic examples:
  #
  #   xml.em("emphasized")                              # => <em>emphasized</em>
  #   xml.em { xml.b("emp & bold") }                    # => <em><b>emph &amp; bold</b></em>
  #   xml.a("A Link", "href"=>"http://onestepback.org") # => <a href="http://onestepback.org">A Link</a>
  #   xm.target("name"=>"compile", "option"=>"fast")    # => <target option="fast" name="compile"\>
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
  class Base
    include ERB::Util
    
    attr_reader :first_render
    attr_accessor :base_path, :assigns, :template_extension
    attr_accessor :controller

    # Turn on to cache the reading of templates from the file system. Doing so means that you have to restart the server
    # when changing templates, but that rendering will be faster.
    @@cache_template_loading = false
    cattr_accessor :cache_template_loading

    @@compiled_erb_templates = {}
    @@loaded_templates = {}

    def self.load_helpers(helper_dir)#:nodoc:
      Dir.foreach(helper_dir) do |helper_file| 
        next unless helper_file =~ /_helper.rb$/
        require helper_dir + helper_file
        helper_module_name = helper_file.capitalize.gsub(/_([a-z])/) { |m| $1.capitalize }[0..-4]

        class_eval("include ActionView::Helpers::#{helper_module_name}") if Helpers.const_defined?(helper_module_name)
      end
    end

    def self.controller_delegate(*methods)#:nodoc:
      methods.flatten.each do |method|
        class_eval <<-end_eval
          def #{method}(*args, &block)
            controller.send(%(#{method}), *args, &block)
          end
        end_eval
      end
    end

    def initialize(base_path = nil, assigns_for_first_render = {}, controller = nil)#:nodoc:
      @base_path, @assigns = base_path, assigns_for_first_render
      @controller = controller
    end

    # Renders the template present at <tt>template_path</tt>. If <tt>use_full_path</tt> is set to true, 
    # it's relative to the template_root, otherwise it's absolute. The hash in <tt>local_assigns</tt> 
    # is made available as local variables.
    def render_file(template_path, use_full_path = true, local_assigns = {})
      @first_render      = template_path if @first_render.nil?
      
      if use_full_path
        template_extension = pick_template_extension(template_path)
        template_file_name = full_template_path(template_path, template_extension)
      else
        template_file_name = template_path
        template_extension = template_path.split(".").last
      end
      
      template_source = read_template_file(template_file_name)

      begin
        render_template(template_extension, template_source, local_assigns)
      rescue Exception => e
        if TemplateError === e
          e.sub_template_of(template_file_name)
          raise e
        else
          raise TemplateError.new(@base_path, template_file_name, @assigns, template_source, e)
        end
      end
    end
    
    # Renders the template present at <tt>template_path</tt> (relative to the template_root). 
    # The hash in <tt>local_assigns</tt> is made available as local variables.
    def render(template_path, local_assigns = {})
      render_file(template_path, true, local_assigns)
    end
    
    # Renders the +template+ which is given as a string as either rhtml or rxml depending on <tt>template_extension</tt>.
    # The hash in <tt>local_assigns</tt> is made available as local variables.
    def render_template(template_extension, template, local_assigns = {})
      b = binding
      local_assigns.each { |key, value| eval "#{key} = local_assigns[\"#{key}\"]", b }
      @assigns.each { |key, value| instance_variable_set "@#{key}", value }
      xml = Builder::XmlMarkup.new(:indent => 2)
      
      send(pick_rendering_method(template_extension), template, binding)
    end

    def pick_template_extension(template_path)#:nodoc:
      if erb_template_exists?(template_path)
        "rhtml"
      elsif builder_template_exists?(template_path)
        "rxml"
      else
        raise ActionViewError, "No rhtml or rxml template found for #{template_path}"
      end
    end
    
    def pick_rendering_method(template_extension)#:nodoc:
      (template_extension == "rxml" ? "rxml" : "rhtml") + "_render"
    end

    def erb_template_exists?(template_path)#:nodoc:
      template_exists?(template_path, "rhtml")
    end

    def builder_template_exists?(template_path)#:nodoc:
      template_exists?(template_path, "rxml")
    end

    def file_exists?(template_path)#:nodoc:
      erb_template_exists?(template_path) || builder_template_exists?(template_path)
    end

    # Returns true is the file may be rendered implicitly.
    def file_public?(template_path)#:nodoc:
      template_path.split("/").last[0,1] != "_"
    end

    private
      def full_template_path(template_path, extension)
        "#{@base_path}/#{template_path}.#{extension}"
      end

      def template_exists?(template_path, extension)
        (cache_template_loading && @@loaded_templates.has_key?(template_path)) ||
          FileTest.exists?(full_template_path(template_path, extension))
      end

      def read_template_file(template_path)
        unless cache_template_loading && @@loaded_templates[template_path]
          @@loaded_templates[template_path] = File.read(template_path)
        end

        @@loaded_templates[template_path]
      end

      def rhtml_render(template, binding)
        @@compiled_erb_templates[template] ||= ERB.new(template, nil, '-')
        @@compiled_erb_templates[template].result(binding)
      end

      def rxml_render(template, binding)
        @controller.headers["Content-Type"] ||= 'text/xml'
        eval(template, binding)
      end
  end
end

require 'action_view/template_error'
