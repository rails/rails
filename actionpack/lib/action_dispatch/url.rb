module ActionDispatch
  class Url
    IP_HOST_REGEXP  = /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/
    HOST_REGEXP     = /(^.*:\/\/)?([^:]+)(?::(\d+$))?/
    PROTOCOL_REGEXP = /^([^:]+)(:)?(\/\/)?$/

    class << self
      def tld_length
        @tld_length ||= 1
      end
      attr_writer :tld_length
    end

    def initialize(options={})
      options = options.dup

      if match = options[:host] && options[:host].to_s.match(HOST_REGEXP)
        options[:host_protocol] = match[1]
        options[:host]          = match[2]
        options[:host_port]     = match[3]
      end

      if options[:path].to_s.include?('?')
        path, query = options[:path].split('?')
        params = options[:params] || {}
        options[:path] = path
        options[:params] = Rack::Utils.parse_nested_query(query).merge(params)
      end

      if options[:path].to_s.include?('#')
        path, anchor = options[:path].split('#')
        options[:path] = path
        options[:anchor] = anchor if options[:anchor].blank?
      end

      @options = options
    end

    attr_reader :options

    def absolute_path
      [ protocol_string, auth_string, host_string, port_string, relative_path ].join('')
    end

    def relative_path
      path = [ script_name_string, path_string ].join('')
      path << trailing_slash_string unless path.end_with?('/')
      path << [ params_string, anchor_string ].join('')
    end

    def protocol_string
      protocol = options[:protocol].nil? ? options[:host_protocol] : options[:protocol]

      case protocol
      when nil
        'http://'
      when false, '//'
        '//'
      when PROTOCOL_REGEXP
        "#{$1}://"
      else
        raise ArgumentError, "Invalid :protocol option: #{protocol.inspect}"
      end
    end

    def auth_string
      user, password = options[:user], options[:password]
      if user && password
        "#{Rack::Utils.escape(user)}:#{Rack::Utils.escape(password)}@"
      else
        ''
      end
    end

    def host_string
      if options[:host].blank?
        raise ArgumentError, 'Missing host to link to! Please provide the :host parameter, set default_url_options[:host], or set :only_path to true'
      end

      if options[:host] =~ IP_HOST_REGEXP
        if options[:domain].blank?
          subdomain, domain = nil, options[:host]
        else
          subdomain, domain = options[:subdomain], options[:domain]
        end
      else
        subdomain, domain = split_host(options[:host])
        subdomain = options[:subdomain] if options.key?(:subdomain) && options[:subdomain] != true
      end

      subdomain = subdomain.to_param if subdomain.present?
      domain = options[:domain] if options[:domain].present?
      domain = domain.chomp('/')

      subdomain.blank? ? domain : "#{subdomain}.#{domain}"
    end

    def tld_length
      (options[:tld_length] || self.class.tld_length).to_i
    end

    def port_string
      return '' unless options.fetch(:port, true)
      port = options[:port].presence || options[:host_port]
      return '' unless port

      if standard_port?(protocol_string, port.to_i)
        ''
      else
        ":#{port}"
      end
    end

    def script_name_string
      return '' unless options[:script_name]
      options[:script_name].chomp('/')
    end

    def path_string
      return '' unless options[:path]
      if options[:path] == '/'
        '/'
      else
        options[:path].chomp('/')
      end
    end

    def trailing_slash_string
      options[:trailing_slash] ? '/' : ''
    end

    def params_string
      return '' if options[:params].blank?
      params = options[:params].to_query
      params.blank? ? '' : "?#{params}"
    end

    def anchor_string
      return '' if options[:anchor].blank?
      anchor = ActionDispatch::Journey::Router::Utils.escape_fragment(options[:anchor].to_param)
      anchor.blank? ? '' : "##{anchor}"
    end

    private

    def split_host(host)
      parts = host.split('.')
      [ parts[0..-(tld_length + 2)].join('.'), parts.last(tld_length + 1).join('.') ]
    end

    def standard_port?(protocol, port)
      case protocol
      when 'http://'
        port == 80
      when 'https://'
        port == 443
      when '//'
        port == 80 || port == 443
      else
        false
      end
    end
  end
end
