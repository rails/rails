require 'cgi'
require 'action_controller/vendor/xml_node'
require 'strscan'

# Static methods for parsing the query and request parameters that can be used in
# a CGI extension class or testing in isolation.
class CGIMethods #:nodoc:
  
  class << self
    # Returns a hash with the pairs from the query string. The implicit hash construction that is done in
    # parse_request_params is not done here.
    def parse_query_parameters(query_string)
      QueryStringScanner.new(query_string).parse
    end

    # Returns the request (POST/GET) parameters in a parsed form where pairs such as "customer[address][street]" / 
    # "Somewhere cool!" are translated into a full hash hierarchy, like
    # { "customer" => { "address" => { "street" => "Somewhere cool!" } } }
    def parse_request_parameters(params)
      parsed_params = {}

      for key, value in params
        next unless key
        value = [value] if key =~ /.*\[\]$/
        unless key.include?('[')
          # much faster to test for the most common case first (GET)
          # and avoid the call to build_deep_hash
          parsed_params[key] = get_typed_value(value[0])
        else
          build_deep_hash(get_typed_value(value[0]), parsed_params, get_levels(key))
        end
      end
    
      parsed_params
    end

    def parse_formatted_request_parameters(mime_type, raw_post_data)
      case strategy = ActionController::Base.param_parsers[mime_type]
        when Proc
          strategy.call(raw_post_data)
        when :xml_simple
          raw_post_data.blank? ? {} : Hash.create_from_xml(raw_post_data)
        when :yaml
          YAML.load(raw_post_data)
        when :xml_node
          node = XmlNode.from_xml(raw_post_data)
          { node.node_name => node }
      end
    rescue Object => e
      { "exception" => "#{e.message} (#{e.class})", "backtrace" => e.backtrace, 
        "raw_post_data" => raw_post_data, "format" => mime_type }
    end

    private
      def get_typed_value(value)
        # test most frequent case first
        if value.is_a?(String)
          value
        elsif value.respond_to?(:content_type) && ! value.content_type.blank?
          # Uploaded file
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

        elsif value.respond_to?(:read)
          # Value as part of a multipart request
          result = value.read
          value.rewind
          result
        elsif value.class == Array
          value.collect { |v| get_typed_value(v) }
        else
          # other value (neither string nor a multipart request)
          value.to_s
        end
      end
  
      PARAMS_HASH_RE = /^([^\[]+)(\[.*\])?(.)?.*$/
      def get_levels(key)
        all, main, bracketed, trailing = PARAMS_HASH_RE.match(key).to_a
        if main.nil?
          []
        elsif trailing
          [key]
        elsif bracketed
          [main] + bracketed.slice(1...-1).split('][')
        else
          [main]
        end
      end

      def build_deep_hash(value, hash, levels)
        if levels.length == 0
          value
        elsif hash.nil?
          { levels.first => build_deep_hash(value, nil, levels[1..-1]) }
        else
          hash.update({ levels.first => build_deep_hash(value, hash[levels.first], levels[1..-1]) })
        end
      end
  end

  class QueryStringScanner < StringScanner
    attr_reader :top, :parent, :result

    def initialize(string)
      super(string)
    end
    
    KEY_REGEXP = %r{([^\[\]=&]+)}
    BRACKETED_KEY_REGEXP = %r{\[([^\[\]=&]+)\]}
    
    # Parse the query string
    def parse
      @result = {}
      until eos?
        # Parse each & delimited chunk
        @parent, @top = nil, result
        
        # First scan the bare key
        key = scan(KEY_REGEXP) or (skip_term and next)
        key = post_key_check(key)
        
        # Then scan as many nestings as present
        until check(/\=/) || eos? 
          r = scan(BRACKETED_KEY_REGEXP) or (skip_term and break)
          key = self[1]
          key = post_key_check(key)
        end
        
        # Scan the value if we see an =
        if scan %r{=}
          value = scan(/[^\&]+/) # scan_until doesn't handle \Z
          value = CGI.unescape(value) if value # May be nil when eos?
          bind key, value
        end
        scan %r/\&+/ # Ignore multiple adjacent &'s
        
      end
      
      return result
    end
    
    # Skip over the current term by scanning past the next &, or to
    # then end of the string if there is no next &
    def skip_term
      scan_until(%r/\&+/) || scan(/.+/)
    end
    
    # After we see a key, we must look ahead to determine our next action. Cases:
    # 
    #   [] follows the key. Then the value must be an array.
    #   = follows the key. (A value comes next)
    #   & or the end of string follows the key. Then the key is a flag.
    #   otherwise, a hash follows the key. 
    def post_key_check(key)
      if eos? || check(/\&/) # a& or a\Z indicates a is a flag.
        bind key, nil # Curiously enough, the flag's value is nil
        nil
      elsif scan(/\[\]/) # a[b][] indicates that b is an array
        container key, Array
        nil
      elsif check(/\[[^\]]/) # a[b] indicates that a is a hash
        container key, Hash
        nil
      else # Presumably an = sign is next.
        key
      end
    end
    
    # Add a container to the stack.
    # 
    def container(key, klass)
      raise TypeError if top.is_a?(Hash) && top.key?(key) && ! top[key].is_a?(klass)
      value = bind(key, klass.new)
      raise TypeError unless value.is_a? klass
      push value
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
            top << {key => value}
            push top.last
          end
        else
          top << value
        end
      elsif top.is_a? Hash
        key = CGI.unescape(key)
        if top.key?(key) && parent.is_a?(Array)
          parent << (@top = {})
        end
        return top[key] ||= value
      else
        # Do nothing?
      end
      return value
    end
  end
end