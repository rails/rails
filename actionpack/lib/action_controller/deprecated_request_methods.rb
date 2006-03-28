module ActionController
  class AbstractRequest
    # Determine whether the body of a HTTP call is URL-encoded (default)
    # or matches one of the registered param_parsers. 
    #
    # For backward compatibility, the post format is extracted from the
    # X-Post-Data-Format HTTP header if present.
    def post_format
      case content_type.to_s
      when 'application/xml'
        :xml
      when 'application/x-yaml'
        :yaml
      else
        :url_encoded
      end
    end

    # Is this a POST request formatted as XML or YAML?
    def formatted_post?
      post? && (post_format == :yaml || post_format == :xml)
    end

    # Is this a POST request formatted as XML?
    def xml_post?
      post? && post_format == :xml
    end

    # Is this a POST request formatted as YAML?
    def yaml_post?
      post? && post_format == :yaml
    end
  end
end
