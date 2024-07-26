require 'cgi'

# Static methods for parsing the query and request parameters that can be used in
# a CGI extension class or testing in isolation.
class CGIMethods #:nodoc:
  public
    # Returns a hash with the pairs from the query string. The implicit hash construction that is done in
    # parse_request_params is not done here.
    def CGIMethods.parse_query_parameters(query_string)
      parsed_params = {}
  
      query_string.split(/[&;]/).each { |p| 
        k, v = p.split('=')

        k = CGI.unescape(k) unless k.nil?
        v = CGI.unescape(v) unless v.nil?

        if k =~ /(.*)\[\]$/
            if parsed_params.has_key? $1
                parsed_params[$1] << v
            else
                parsed_params[$1] = [v]
            end
        else
            parsed_params[k] = v.nil? ? nil : v
        end
      }
  
      return parsed_params
    end
  
    # Returns the request (POST/GET) parameters in a parsed form where pairs such as "customer[address][street]" / 
    # "Somewhere cool!" are translated into a full hash hierarchy, like
    # { "customer" => { "address" => { "street" => "Somewhere cool!" } } }
    def CGIMethods.parse_request_parameters(params)
      parsed_params = {}

      for key, value in params
        value = [value] if key =~ /.*\[\]$/
        CGIMethods.build_deep_hash(
          CGIMethods.get_typed_value(value[0]),
          parsed_params, 
          CGIMethods.get_levels(key)
        )
      end
    
      return parsed_params
    end

  private
    def CGIMethods.get_typed_value(value)
      if value.respond_to?(:content_type) && !value.content_type.empty?
        # Uploaded file
        value
      elsif value.respond_to?(:read)
        # Value as part of a multipart request
        value.read
      elsif value.class == Array
          value
      else
        # Standard value (not a multipart request)
        value.to_s
      end
    end
  
    def CGIMethods.get_levels(key_string)
      return [] if key_string.nil? or key_string.empty?

      levels = []
      main, existance = /(\w+)(\[)?.?/.match(key_string).captures
      levels << main
      
      unless existance.nil?
        hash_part = key_string.sub(/\w+\[/, "")
        hash_part.slice!(-1, 1)
        levels += hash_part.split(/\]\[/)
      end
      
      levels
    end
    
    def CGIMethods.build_deep_hash(value, hash, levels)
      if levels.length == 0
        value;
      elsif hash.nil?
        { levels.first => CGIMethods.build_deep_hash(value, nil, levels[1..-1]) }
      else
        hash.update({ levels.first => CGIMethods.build_deep_hash(value, hash[levels.first], levels[1..-1]) })
      end
    end
end