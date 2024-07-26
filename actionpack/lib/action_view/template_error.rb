module ActionView
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
end