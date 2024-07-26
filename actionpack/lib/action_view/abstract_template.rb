require 'erb'

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

  class AbstractTemplate
    attr_reader :first_render
    attr_accessor :base_path, :assigns, :template_extension
    attr_accessor :controller

    def self.load_helpers(helper_dir)
      Dir.foreach(helper_dir) do |helper_file| 
        next unless helper_file =~ /_helper.rb$/
        require helper_dir + helper_file
        helper_module_name = helper_file.capitalize.gsub(/_([a-z])/) { |m| $1.capitalize }[0..-4]

        class_eval("include ActionView::Helpers::#{helper_module_name}") if Helpers.const_defined?(helper_module_name)
      end
    end

    def initialize(base_path = nil, assigns_for_first_render = {}, controller = nil)
      @base_path, @template_extension, @assigns = base_path, template_extension, assigns_for_first_render
      @controller = controller
      @template_extension = "rhtml"
    end

    def render_file(template_path, use_full_path = true)
      @first_render      = template_path if @first_render.nil?
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
    
    # Must be implemented by concrete template class
    def render_template(template) end
    def file_exists?(template_path) end

    private
      def full_template_path(template_path) end
      def read_template_file(template_path) end
  end
end