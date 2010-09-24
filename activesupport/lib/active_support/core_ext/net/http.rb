require 'uri'
require 'net/http'

module Net
  class HTTP
    # Follows a HTTP redirect. It makes sense because the method returns
    # the response body.
    def HTTP.get(uri_or_host, path = nil, port = nil)
      response = get_response(uri_or_host, path, port)
      case response
        when HTTPSuccess, HTTPRedirection
          if response.header['location'] !=nil
            new_url = URI.parse(response.header['location'])
            if new_url.relative?
               new_url = uri_or_host + new_url
            end
            response = get_response(new_url, path, port)
          end
      else
        response.error!
      end
      response.body
    end
  end
end
