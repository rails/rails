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
      if original_exception.message.include?("(eval):")
        original_exception.message.scan(/\(eval\):(?:[0-9]*):in `.*'(.*)/).first.first
      else
        original_exception.message
      end
    end
  
    def sub_template_message
      if @sub_templates
        "Trace of template inclusion: " +
        @sub_templates.collect { |template| strip_base_path(template) }.join(", ")
      else
        ""
      end
    end
  
    def source_extract(indention = 0)
      source_code = IO.readlines(@file_name)
      
      start_on_line = [ line_number - SOURCE_CODE_RADIUS - 1, 0 ].max
      end_on_line   = [ line_number + SOURCE_CODE_RADIUS - 1, source_code.length].min

      line_counter = start_on_line
      extract = source_code[start_on_line..end_on_line].collect do |line| 
        line_counter += 1
        "#{' ' * indention}#{line_counter}: " + line
      end

      extract.join
    end
  
    def sub_template_of(file_name)
      @sub_templates ||= []
      @sub_templates << file_name
    end
  
    def line_number
      trace = @original_exception.backtrace.join
      if trace.include?("erb):")
        trace.scan(/\((?:erb)\):([0-9]*)/).first.first.to_i
      elsif trace.include?("eval):")
        trace.scan(/\((?:eval)\):([0-9]*)/).first.first.to_i
      else
        1
      end
    end
  
    def file_name
      strip_base_path(@file_name)
    end
    
    def to_s
      "\n\n#{self.class} (#{message}) on line ##{line_number} of #{file_name}:\n" + 
      source_extract + "\n    " +
      clean_backtrace(original_exception).join("\n    ") +
      "\n\n"
    end

    def backtrace
      [ 
        "On line ##{line_number} of #{file_name}\n\n#{source_extract(4)}\n    " + 
        clean_backtrace(original_exception).join("\n    ")
      ]
    end

    private
      def strip_base_path(file_name)
        file_name.gsub(@base_path, "")
      end

      def clean_backtrace(exception)
        base_dir = File.expand_path(File.dirname(__FILE__) + "/../../../../")
        exception.backtrace.collect { |line| line.gsub(base_dir, "").gsub("/public/../config/environments/../../", "").gsub("/public/../", "") }
      end
  end
end