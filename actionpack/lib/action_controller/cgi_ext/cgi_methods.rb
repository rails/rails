require 'cgi'
require 'action_controller/vendor/xml_node'
require 'strscan'

# Static methods for parsing the query and request parameters that can be used in
# a CGI extension class or testing in isolation.
class CGIMethods #:nodoc:
  class << self
    # DEPRECATED: Use parse_form_encoded_parameters
    def parse_query_parameters(query_string)
      pairs = query_string.split('&').collect do |chunk|
        next if chunk.empty?
        key, value = chunk.split('=', 2)
        next if key.empty?
        value = (value.nil? || value.empty?) ? nil : CGI.unescape(value)
        [ CGI.unescape(key), value ]
      end.compact

      FormEncodedPairParser.new(pairs).result
    end

    # DEPRECATED: Use parse_form_encoded_parameters
    def parse_request_parameters(params)
      parser = FormEncodedPairParser.new

      finished = false
      until finished
        finished = true
        for key, value in params
          next if key.blank?
          if !key.include?('[')
            # much faster to test for the most common case first (GET)
            # and avoid the call to build_deep_hash
            parser.result[key] = get_typed_value(value[0])
          elsif value.is_a?(Array)
            parser.parse(key, get_typed_value(value.shift))
            finished = false unless value.empty?
          else
            raise TypeError, "Expected array, found #{value.inspect}"
          end
        end
      end
    
      parser.result
    end

    def parse_formatted_request_parameters(mime_type, raw_post_data)
      case strategy = ActionController::Base.param_parsers[mime_type]
        when Proc
          strategy.call(raw_post_data)
        when :xml_simple
          raw_post_data.blank? ? {} : Hash.from_xml(raw_post_data)
        when :yaml
          YAML.load(raw_post_data)
        when :xml_node
          node = XmlNode.from_xml(raw_post_data)
          { node.node_name => node }
      end
    rescue Exception => e # YAML, XML or Ruby code block errors
      { "exception" => "#{e.message} (#{e.class})", "backtrace" => e.backtrace, 
        "raw_post_data" => raw_post_data, "format" => mime_type }
    end

    private
      def get_typed_value(value)
        case value
          when String
            value
          when NilClass
            ''
          when Array
            value.map { |v| get_typed_value(v) }
          else
            # Uploaded file provides content type and filename.
            if value.respond_to?(:content_type) &&
                  !value.content_type.blank? &&
                  !value.original_filename.blank?
              unless value.respond_to?(:full_original_filename)
                class << value
                  alias_method :full_original_filename, :original_filename

                  # Take the basename of the upload's original filename.
                  # This handles the full Windows paths given by Internet Explorer
                  # (and perhaps other broken user agents) without affecting
                  # those which give the lone filename.
                  # The Windows regexp is adapted from Perl's File::Basename.
                  def original_filename
                    if md = /^(?:.*[:\\\/])?(.*)/m.match(full_original_filename)
                      md.captures.first
                    else
                      File.basename full_original_filename
                    end
                  end
                end
              end

              # Return the same value after overriding original_filename.
              value

            # Multipart values may have content type, but no filename.
            elsif value.respond_to?(:read)
              result = value.read
              value.rewind
              result

            # Unknown value, neither string nor multipart.
            else
              raise "Unknown form value: #{value.inspect}"
            end
        end
      end
  end

  class FormEncodedPairParser < StringScanner
    attr_reader :top, :parent, :result

    def initialize(pairs = [])
      super('')
      @result = {}
      pairs.each { |key, value| parse(key, value) }
    end
     
    KEY_REGEXP = %r{([^\[\]=&]+)}
    BRACKETED_KEY_REGEXP = %r{\[([^\[\]=&]+)\]}
    
    # Parse the query string
    def parse(key, value)
      self.string = key
      @top, @parent = result, nil
      
      # First scan the bare key
      key = scan(KEY_REGEXP) or return
      key = post_key_check(key)
            
      # Then scan as many nestings as present
      until eos? 
        r = scan(BRACKETED_KEY_REGEXP) or return
        key = self[1]
        key = post_key_check(key)
      end
 
      bind(key, value)
    end

    private
      # After we see a key, we must look ahead to determine our next action. Cases:
      # 
      #   [] follows the key. Then the value must be an array.
      #   = follows the key. (A value comes next)
      #   & or the end of string follows the key. Then the key is a flag.
      #   otherwise, a hash follows the key. 
      def post_key_check(key)
        if scan(/\[\]/) # a[b][] indicates that b is an array
          container(key, Array)
          nil
        elsif check(/\[[^\]]/) # a[b] indicates that a is a hash
          container(key, Hash)
          nil
        else # End of key? We do nothing.
          key
        end
      end
    
      # Add a container to the stack.
      # 
      def container(key, klass)
        type_conflict! klass, top[key] if top.is_a?(Hash) && top.key?(key) && ! top[key].is_a?(klass)
        value = bind(key, klass.new)
        type_conflict! klass, value unless value.is_a?(klass)
        push(value)
      end
    
      # Push a value onto the 'stack', which is actually only the top 2 items.
      def push(value)
        @parent, @top = @top, value
      end
    
      # Bind a key (which may be nil for items in an array) to the provided value.
      def bind(key, value)
        if top.is_a? Array
          if key
            if top[-1].is_a?(Hash) && ! top[-1].key?(key)
              top[-1][key] = value
            else
              top << {key => value}.with_indifferent_access
              push top.last
            end
          else
            top << value
          end
        elsif top.is_a? Hash
          key = CGI.unescape(key)
          parent << (@top = {}) if top.key?(key) && parent.is_a?(Array)
          return top[key] ||= value
        else
          raise ArgumentError, "Don't know what to do: top is #{top.inspect}"
        end

        return value
      end
      
      def type_conflict!(klass, value)
        raise TypeError, 
          "Conflicting types for parameter containers. " +
          "Expected an instance of #{klass}, but found an instance of #{value.class}. " +
          "This can be caused by passing Array and Hash based paramters qs[]=value&qs[key]=value. "
      end
      
    end
end
