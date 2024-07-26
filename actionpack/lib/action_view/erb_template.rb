require 'erb'

# Action View templates are written using a mixture of HTML and eRuby tags. eRuby is short for embedded Ruby and that's pretty
# much all the magic there is to it. Plain Ruby inserted into HTML (or XML or something else). You trigger eRuby by using embeddings
# such as <% %> and <%= %>. The difference is whether you want output or not. Consider the following loop for names:
#
#   <b>Names of all the people</b>
#   <% for person in @people %>
#     Name: <%= person.name %><br/>
#   <% end %>
#
# The loop is setup in regular embedding tags (<% %>) and the name is written using the output embedding tag (<%= %>). Note that this
# is not just a usage suggestion. Regular output functions like print or puts won't work with eRuby templates. So this would be wrong:
#
#   Hi, Mr. <% puts "Frodo" %>
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
#    <title><%= @page_title %></title>
#
# == Other template engines
#
# The ERbTemplate is the default Action View class used by the Action Controller. If you want to use a different
# class, you'll need to implement this interface, and use the Base.template_class=. There is already one other implementation 
# available. That's the ErubyTemplate, which is functionally identical to the default ERbTemplate, but uses the C-version of eRuby.
module ActionView
  class ActionViewError < Exception #:nodoc:
  end

  # The TemplateError exception is raised when the compilation of the template fails. This exception then gathers a
  # bunch of intimate details and uses it to report a very precise exception message.
  class TemplateError < ActionViewError #:nodoc:
    SOURCE_CODE_RADIUS = 3
  
    attr_reader :original_exception
  
    def initialize(base_path, file_name, assigns, source, original_exception)
      @base_path, @file_name, @assigns, @source, @original_exception = 
        base_path, file_name, assigns, source, original_exception
    end
    
    def message
      @last_message
    end
    
    def sub_template_message
      if @sub_templates
        "Trace of template inclusion: " +
        @sub_templates.collect { |template| strip_base_path(template) }.join(", ")
      else
        ""
      end
    end
    
    def source_extract
      source_code = IO.readlines(@file_name)
      start_on_line = [ line_number - SOURCE_CODE_RADIUS - 1, 0 ].max
      end_on_line   = [ line_number + SOURCE_CODE_RADIUS - 1, source_code.length].min

      line_counter = start_on_line
      extract = source_code[start_on_line..end_on_line].collect do |line| 
        line_counter += 1
        "#{line_counter}: " + line
      end
      
      extract.join
    end
    
    def sub_template_of(file_name)
      @sub_templates ||= []
      @sub_templates << file_name
    end
    
    def line_number
      @original_exception.backtrace.join.scan(/\(erb\):([0-9]*)/).first.first.to_i
    end
    
    def file_name
      strip_base_path(@file_name)
    end

    private
      def strip_base_path(file_name)
        file_name.gsub(@base_path, "")
      end
    
  end

  class ERbTemplate#:nodoc:
    attr_reader :first_render
    attr_accessor :base_path, :assigns, :template_extension
    attr_accessor :controller
    
    def initialize(base_path = nil, assigns_for_first_render = {}, controller = nil)
      @base_path, @template_extension, @assigns = base_path, template_extension, assigns_for_first_render
      @controller = controller
      @template_extension = "rhtml"
    end

    def render_file(template_path, use_full_path = true)
      @first_render = template_path if @first_render.nil?
      template_file_name = use_full_path ? full_template_path(template_path) : template_path
      template_source    = read_template_file(template_file_name)

      begin
        render_template(template_source)
      rescue Exception => e
        if TemplateError === e
          e.sub_template_of(template_file_name)
          raise e
        else
          raise TemplateError.new(@base_path, template_file_name, @assigns, template_source, e)
        end
      end
    end
    alias_method :render, :render_file

    def render_template(template)
      @assigns.each { |key, value| instance_variable_set "@#{key}", value }
      template_render(template, binding)
    end
    
    def file_exists?(template_path)
      FileTest.exists?(full_template_path(template_path))
    end

    private
      def full_template_path(template_path)
        "#{@base_path}/#{template_path}.#{@template_extension}"
      end
    
      def read_template_file(template_path)
        IO.readlines(template_path).join
      end
      
      def template_render(template, binding)
        ERB.new(template).result(binding)
      end
  end
end