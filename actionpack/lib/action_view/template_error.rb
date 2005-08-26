module ActionView
  # The TemplateError exception is raised when the compilation of the template fails. This exception then gathers a
  # bunch of intimate details and uses it to report a very precise exception message.
  class TemplateError < ActionViewError #:nodoc:
    SOURCE_CODE_RADIUS = 3

    attr_reader :original_exception

    def initialize(base_path, file_name, assigns, source, original_exception)
      @base_path, @assigns, @source, @original_exception = 
        base_path, assigns, source, original_exception
      @file_name = File.expand_path file_name
    end
  
    def message
      original_exception.message
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
      if @file_name
        regexp = /#{Regexp.escape @file_name}(?:\(.*?\))?:(\d+)/ # A regexp to match a line number in our file
        [@original_exception.message, @original_exception.backtrace].flatten.each do |line|
          return $1.to_i if regexp =~ line
        end
      end
      0
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
        file_name = File.expand_path(file_name).gsub(/^#{Regexp.escape File.expand_path(RAILS_ROOT)}/, '')
        file_name.gsub(@base_path, "")
      end

      if defined?(RAILS_ROOT)
        RailsRootRegexp = %r((#{Regexp.escape RAILS_ROOT}|#{Regexp.escape File.expand_path(RAILS_ROOT)})/(.*)?)
      else
        RailsRootRegexp = /^()(.*)$/
      end

      def clean_backtrace(exception)
        exception.backtrace.collect do |line|
          line.gsub %r{^(\s*)(/[-\w\d\./]+)} do
            leading, path = $1, $2
            path = $2 if RailsRootRegexp =~ path
            leading + path
          end
        end
      end
  end
end
