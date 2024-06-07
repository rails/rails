# frozen_string_literal: true

# :markup: markdown

require "active_support/core_ext/hash/keys"
require "active_support/key_generator"
require "active_support/message_verifier"
require "active_support/json"
require "rack/utils"

module ActionDispatch
  module RequestCookieMethods
    def cookie_jar
      fetch_header("action_dispatch.cookies") do
        self.cookie_jar = Cookies::CookieJar.build(self, cookies)
      end
    end

    # :stopdoc:
    prepend Module.new {
      def commit_cookie_jar!
        cookie_jar.commit!
      end
    }

    def have_cookie_jar?
      has_header? "action_dispatch.cookies"
    end

    def cookie_jar=(jar)
      set_header "action_dispatch.cookies", jar
    end

    def key_generator
      get_header Cookies::GENERATOR_KEY
    end

    def signed_cookie_salt
      get_header Cookies::SIGNED_COOKIE_SALT
    end

    def encrypted_cookie_salt
      get_header Cookies::ENCRYPTED_COOKIE_SALT
    end

    def encrypted_signed_cookie_salt
      get_header Cookies::ENCRYPTED_SIGNED_COOKIE_SALT
    end

    def authenticated_encrypted_cookie_salt
      get_header Cookies::AUTHENTICATED_ENCRYPTED_COOKIE_SALT
    end

    def use_authenticated_cookie_encryption
      get_header Cookies::USE_AUTHENTICATED_COOKIE_ENCRYPTION
    end

    def encrypted_cookie_cipher
      get_header Cookies::ENCRYPTED_COOKIE_CIPHER
    end

    def signed_cookie_digest
      get_header Cookies::SIGNED_COOKIE_DIGEST
    end

    def secret_key_base
      get_header Cookies::SECRET_KEY_BASE
    end

    def cookies_serializer
      get_header Cookies::COOKIES_SERIALIZER
    end

    def cookies_same_site_protection
      get_header(Cookies::COOKIES_SAME_SITE_PROTECTION)&.call(self)
    end

    def cookies_digest
      get_header Cookies::COOKIES_DIGEST
    end

    def cookies_rotations
      get_header Cookies::COOKIES_ROTATIONS
    end

    def use_cookies_with_metadata
      get_header Cookies::USE_COOKIES_WITH_METADATA
    end

    # :startdoc:
  end

  ActiveSupport.on_load(:action_dispatch_request) do
    include RequestCookieMethods
  end

  # Read and write data to cookies through ActionController::Cookies#cookies.
  #
  # When reading cookie data, the data is read from the HTTP request header,
  # Cookie. When writing cookie data, the data is sent out in the HTTP response
  # header, `Set-Cookie`.
  #
  # Examples of writing:
  #
  #     # Sets a simple session cookie.
  #     # This cookie will be deleted when the user's browser is closed.
  #     cookies[:user_name] = "david"
  #
  #     # Cookie values are String-based. Other data types need to be serialized.
  #     cookies[:lat_lon] = JSON.generate([47.68, -122.37])
  #
  #     # Sets a cookie that expires in 1 hour.
  #     cookies[:login] = { value: "XJ-122", expires: 1.hour }
  #
  #     # Sets a cookie that expires at a specific time.
  #     cookies[:login] = { value: "XJ-122", expires: Time.utc(2020, 10, 15, 5) }
  #
  #     # Sets a signed cookie, which prevents users from tampering with its value.
  #     # It can be read using the signed method `cookies.signed[:name]`
  #     cookies.signed[:user_id] = current_user.id
  #
  #     # Sets an encrypted cookie value before sending it to the client which
  #     # prevent users from reading and tampering with its value.
  #     # It can be read using the encrypted method `cookies.encrypted[:name]`
  #     cookies.encrypted[:discount] = 45
  #
  #     # Sets a "permanent" cookie (which expires in 20 years from now).
  #     cookies.permanent[:login] = "XJ-122"
  #
  #     # You can also chain these methods:
  #     cookies.signed.permanent[:login] = "XJ-122"
  #
  # Examples of reading:
  #
  #     cookies[:user_name]           # => "david"
  #     cookies.size                  # => 2
  #     JSON.parse(cookies[:lat_lon]) # => [47.68, -122.37]
  #     cookies.signed[:login]        # => "XJ-122"
  #     cookies.encrypted[:discount]  # => 45
  #
  # Example for deleting:
  #
  #     cookies.delete :user_name
  #
  # Please note that if you specify a `:domain` when setting a cookie, you must
  # also specify the domain when deleting the cookie:
  #
  #     cookies[:name] = {
  #       value: 'a yummy cookie',
  #       expires: 1.year,
  #       domain: 'domain.com'
  #     }
  #
  #     cookies.delete(:name, domain: 'domain.com')
  #
  # The option symbols for setting cookies are:
  #
  # *   `:value` - The cookie's value.
  # *   `:path` - The path for which this cookie applies. Defaults to the root of
  #     the application.
  # *   `:domain` - The domain for which this cookie applies so you can restrict
  #     to the domain level. If you use a schema like www.example.com and want to
  #     share session with user.example.com set `:domain` to `:all`. To support
  #     multiple domains, provide an array, and the first domain matching
  #     `request.host` will be used. Make sure to specify the `:domain` option
  #     with `:all` or `Array` again when deleting cookies. For more flexibility
  #     you can set the domain on a per-request basis by specifying `:domain` with
  #     a proc.
  #
  #         domain: nil  # Does not set cookie domain. (default)
  #         domain: :all # Allow the cookie for the top most level
  #                      # domain and subdomains.
  #         domain: %w(.example.com .example.org) # Allow the cookie
  #                                               # for concrete domain names.
  #         domain: proc { Tenant.current.cookie_domain } # Set cookie domain dynamically
  #         domain: proc { |req| ".sub.#{req.host}" }     # Set cookie domain dynamically based on request
  #
  # *   `:tld_length` - When using `:domain => :all`, this option can be used to
  #     explicitly set the TLD length when using a short (<= 3 character) domain
  #     that is being interpreted as part of a TLD. For example, to share cookies
  #     between user1.lvh.me and user2.lvh.me, set `:tld_length` to 2.
  # *   `:expires` - The time at which this cookie expires, as a Time or
  #     ActiveSupport::Duration object.
  # *   `:secure` - Whether this cookie is only transmitted to HTTPS servers.
  #     Default is `false`.
  # *   `:httponly` - Whether this cookie is accessible via scripting or only
  #     HTTP. Defaults to `false`.
  # *   `:same_site` - The value of the `SameSite` cookie attribute, which
  #     determines how this cookie should be restricted in cross-site contexts.
  #     Possible values are `nil`, `:none`, `:lax`, and `:strict`. Defaults to
  #     `:lax`.
  #
  class Cookies
    HTTP_HEADER   = "Set-Cookie"
    GENERATOR_KEY = "action_dispatch.key_generator"
    SIGNED_COOKIE_SALT = "action_dispatch.signed_cookie_salt"
    ENCRYPTED_COOKIE_SALT = "action_dispatch.encrypted_cookie_salt"
    ENCRYPTED_SIGNED_COOKIE_SALT = "action_dispatch.encrypted_signed_cookie_salt"
    AUTHENTICATED_ENCRYPTED_COOKIE_SALT = "action_dispatch.authenticated_encrypted_cookie_salt"
    USE_AUTHENTICATED_COOKIE_ENCRYPTION = "action_dispatch.use_authenticated_cookie_encryption"
    ENCRYPTED_COOKIE_CIPHER = "action_dispatch.encrypted_cookie_cipher"
    SIGNED_COOKIE_DIGEST = "action_dispatch.signed_cookie_digest"
    SECRET_KEY_BASE = "action_dispatch.secret_key_base"
    COOKIES_SERIALIZER = "action_dispatch.cookies_serializer"
    COOKIES_DIGEST = "action_dispatch.cookies_digest"
    COOKIES_ROTATIONS = "action_dispatch.cookies_rotations"
    COOKIES_SAME_SITE_PROTECTION = "action_dispatch.cookies_same_site_protection"
    USE_COOKIES_WITH_METADATA = "action_dispatch.use_cookies_with_metadata"

    # Cookies can typically store 4096 bytes.
    MAX_COOKIE_SIZE = 4096

    # Raised when storing more than 4K of session data.
    CookieOverflow = Class.new StandardError

    # Include in a cookie jar to allow chaining, e.g. `cookies.permanent.signed`.
    module ChainedCookieJars
      # Returns a jar that'll automatically set the assigned cookies to have an
      # expiration date 20 years from now. Example:
      #
      #     cookies.permanent[:prefers_open_id] = true
      #     # => Set-Cookie: prefers_open_id=true; path=/; expires=Sun, 16-Dec-2029 03:24:16 GMT
      #
      # This jar is only meant for writing. You'll read permanent cookies through the
      # regular accessor.
      #
      # This jar allows chaining with the signed jar as well, so you can set
      # permanent, signed cookies. Examples:
      #
      #     cookies.permanent.signed[:remember_me] = current_user.id
      #     # => Set-Cookie: remember_me=BAhU--848956038e692d7046deab32b7131856ab20e14e; path=/; expires=Sun, 16-Dec-2029 03:24:16 GMT
      def permanent
        @permanent ||= PermanentCookieJar.new(self)
      end

      # Returns a jar that'll automatically generate a signed representation of cookie
      # value and verify it when reading from the cookie again. This is useful for
      # creating cookies with values that the user is not supposed to change. If a
      # signed cookie was tampered with by the user (or a 3rd party), `nil` will be
      # returned.
      #
      # This jar requires that you set a suitable secret for the verification on your
      # app's `secret_key_base`.
      #
      # Example:
      #
      #     cookies.signed[:discount] = 45
      #     # => Set-Cookie: discount=BAhpMg==--2c1c6906c90a3bc4fd54a51ffb41dffa4bf6b5f7; path=/
      #
      #     cookies.signed[:discount] # => 45
      def signed
        @signed ||= SignedKeyRotatingCookieJar.new(self)
      end

      # Returns a jar that'll automatically encrypt cookie values before sending them
      # to the client and will decrypt them for read. If the cookie was tampered with
      # by the user (or a 3rd party), `nil` will be returned.
      #
      # If `config.action_dispatch.encrypted_cookie_salt` and
      # `config.action_dispatch.encrypted_signed_cookie_salt` are both set, legacy
      # cookies encrypted with HMAC AES-256-CBC will be transparently upgraded.
      #
      # This jar requires that you set a suitable secret for the verification on your
      # app's `secret_key_base`.
      #
      # Example:
      #
      #     cookies.encrypted[:discount] = 45
      #     # => Set-Cookie: discount=DIQ7fw==--K3n//8vvnSbGq9dA--7Xh91HfLpwzbj1czhBiwOg==; path=/
      #
      #     cookies.encrypted[:discount] # => 45
      def encrypted
        @encrypted ||= EncryptedKeyRotatingCookieJar.new(self)
      end

      # Returns the `signed` or `encrypted` jar, preferring `encrypted` if
      # `secret_key_base` is set. Used by ActionDispatch::Session::CookieStore to
      # avoid the need to introduce new cookie stores.
      def signed_or_encrypted
        @signed_or_encrypted ||=
          if request.secret_key_base.present?
            encrypted
          else
            signed
          end
      end

      private
        def upgrade_legacy_hmac_aes_cbc_cookies?
          request.secret_key_base.present? &&
            request.encrypted_signed_cookie_salt.present? &&
            request.encrypted_cookie_salt.present? &&
            request.use_authenticated_cookie_encryption
        end

        def prepare_upgrade_legacy_hmac_aes_cbc_cookies?
          request.secret_key_base.present? &&
            request.authenticated_encrypted_cookie_salt.present? &&
            !request.use_authenticated_cookie_encryption
        end

        def encrypted_cookie_cipher
          request.encrypted_cookie_cipher || "aes-256-gcm"
        end

        def signed_cookie_digest
          request.signed_cookie_digest || "SHA1"
        end
    end

    class CookieJar # :nodoc:
      include Enumerable, ChainedCookieJars

      def self.build(req, cookies)
        jar = new(req)
        jar.update(cookies)
        jar
      end

      attr_reader :request

      def initialize(request)
        @set_cookies = {}
        @delete_cookies = {}
        @request = request
        @cookies = {}
        @committed = false
      end

      def committed?; @committed; end

      def commit!
        @committed = true
        @set_cookies.freeze
        @delete_cookies.freeze
      end

      def each(&block)
        @cookies.each(&block)
      end

      # Returns the value of the cookie by `name`, or `nil` if no such cookie exists.
      def [](name)
        @cookies[name.to_s]
      end

      def fetch(name, *args, &block)
        @cookies.fetch(name.to_s, *args, &block)
      end

      def key?(name)
        @cookies.key?(name.to_s)
      end
      alias :has_key? :key?

      # Returns the cookies as Hash.
      alias :to_hash :to_h

      def update(other_hash)
        @cookies.update other_hash.stringify_keys
        self
      end

      def update_cookies_from_jar
        request_jar = @request.cookie_jar.instance_variable_get(:@cookies)
        set_cookies = request_jar.reject { |k, _| @delete_cookies.key?(k) || @set_cookies.key?(k) }

        @cookies.update set_cookies if set_cookies
      end

      def to_header
        @cookies.map { |k, v| "#{escape(k)}=#{escape(v)}" }.join "; "
      end

      # Sets the cookie named `name`. The second argument may be the cookie's value or
      # a hash of options as documented above.
      def []=(name, options)
        if options.is_a?(Hash)
          options.symbolize_keys!
          value = options[:value]
        else
          value = options
          options = { value: value }
        end

        handle_options(options)

        if @cookies[name.to_s] != value || options[:expires]
          @cookies[name.to_s] = value
          @set_cookies[name.to_s] = options
          @delete_cookies.delete(name.to_s)
        end

        value
      end

      # Removes the cookie on the client machine by setting the value to an empty
      # string and the expiration date in the past. Like `[]=`, you can pass in an
      # options hash to delete cookies with extra data such as a `:path`.
      #
      # Returns the value of the cookie, or `nil` if the cookie does not exist.
      def delete(name, options = {})
        return unless @cookies.has_key? name.to_s

        options.symbolize_keys!
        handle_options(options)

        value = @cookies.delete(name.to_s)
        @delete_cookies[name.to_s] = options
        value
      end

      # Whether the given cookie is to be deleted by this CookieJar. Like `[]=`, you
      # can pass in an options hash to test if a deletion applies to a specific
      # `:path`, `:domain` etc.
      def deleted?(name, options = {})
        options.symbolize_keys!
        handle_options(options)
        @delete_cookies[name.to_s] == options
      end

      # Removes all cookies on the client machine by calling `delete` for each cookie.
      def clear(options = {})
        @cookies.each_key { |k| delete(k, options) }
      end

      def write(response)
        @set_cookies.each do |name, value|
          if write_cookie?(value)
            response.set_cookie(name, value)
          end
        end

        @delete_cookies.each do |name, value|
          response.delete_cookie(name, value)
        end
      end

      mattr_accessor :always_write_cookie, default: false

      private
        def escape(string)
          ::Rack::Utils.escape(string)
        end

        def write_cookie?(cookie)
          request.ssl? || !cookie[:secure] || always_write_cookie || request.host.end_with?(".onion")
        end

        def handle_options(options)
          if options[:expires].respond_to?(:from_now)
            options[:expires] = options[:expires].from_now
          end

          options[:path]      ||= "/"

          unless options.key?(:same_site)
            options[:same_site] = request.cookies_same_site_protection
          end

          if options[:domain] == :all || options[:domain] == "all"
            cookie_domain = ""
            dot_splitted_host = request.host.split(".", -1)

            # Case where request.host is not an IP address or it's an invalid domain (ip
            # confirms to the domain structure we expect so we explicitly check for ip)
            if request.host.match?(/^[\d.]+$/) || dot_splitted_host.include?("") || dot_splitted_host.length == 1
              options[:domain] = nil
              return
            end

            # If there is a provided tld length then we use it otherwise default domain.
            if options[:tld_length].present?
              # Case where the tld_length provided is valid
              if dot_splitted_host.length >= options[:tld_length]
                cookie_domain = dot_splitted_host.last(options[:tld_length]).join(".")
              end
            # Case where tld_length is not provided
            else
              # Regular TLDs
              if !(/\.[^.]{2,3}\.[^.]{2}\z/.match?(request.host))
                cookie_domain = dot_splitted_host.last(2).join(".")
              # **.**, ***.** style TLDs like co.uk and com.au
              else
                cookie_domain = dot_splitted_host.last(3).join(".")
              end
            end

            options[:domain] = if cookie_domain.present?
              cookie_domain
            end
          elsif options[:domain].is_a? Array
            # If host matches one of the supplied domains.
            options[:domain] = options[:domain].find do |domain|
              domain = domain.delete_prefix(".")
              request.host == domain || request.host.end_with?(".#{domain}")
            end
          elsif options[:domain].respond_to?(:call)
            options[:domain] = options[:domain].call(request)
          end
        end
    end

    class AbstractCookieJar # :nodoc:
      include ChainedCookieJars

      def initialize(parent_jar)
        @parent_jar = parent_jar
      end

      def [](name)
        if data = @parent_jar[name.to_s]
          result = parse(name, data, purpose: "cookie.#{name}")

          if result.nil?
            parse(name, data)
          else
            result
          end
        end
      end

      def []=(name, options)
        if options.is_a?(Hash)
          options.symbolize_keys!
        else
          options = { value: options }
        end

        commit(name, options)
        @parent_jar[name] = options
      end

      protected
        def request; @parent_jar.request; end

      private
        def expiry_options(options)
          if options[:expires].respond_to?(:from_now)
            { expires_in: options[:expires] }
          else
            { expires_at: options[:expires] }
          end
        end

        def cookie_metadata(name, options)
          expiry_options(options).tap do |metadata|
            metadata[:purpose] = "cookie.#{name}" if request.use_cookies_with_metadata
          end
        end

        def parse(name, data, purpose: nil); data; end
        def commit(name, options); end
    end

    class PermanentCookieJar < AbstractCookieJar # :nodoc:
      private
        def commit(name, options)
          options[:expires] = 20.years.from_now
        end
    end

    module SerializedCookieJars # :nodoc:
      SERIALIZER = ActiveSupport::MessageEncryptor::NullSerializer

      protected
        def digest
          request.cookies_digest || "SHA1"
        end

      private
        def serializer
          @serializer ||=
            case request.cookies_serializer
            when nil
              ActiveSupport::Messages::SerializerWithFallback[:marshal]
            when :hybrid
              ActiveSupport::Messages::SerializerWithFallback[:json_allow_marshal]
            when Symbol
              ActiveSupport::Messages::SerializerWithFallback[request.cookies_serializer]
            else
              request.cookies_serializer
            end
        end

        def reserialize?(dumped)
          serializer.is_a?(ActiveSupport::Messages::SerializerWithFallback) &&
            serializer != ActiveSupport::Messages::SerializerWithFallback[:marshal] &&
            !serializer.dumped?(dumped)
        end

        def parse(name, dumped, force_reserialize: false, **)
          if dumped
            begin
              value = serializer.load(dumped)
            rescue StandardError
              return
            end

            self[name] = { value: value } if force_reserialize || reserialize?(dumped)

            value
          end
        end

        def commit(name, options)
          options[:value] = serializer.dump(options[:value])
        end

        def check_for_overflow!(name, options)
          if options[:value].bytesize > MAX_COOKIE_SIZE
            raise CookieOverflow, "#{name} cookie overflowed with size #{options[:value].bytesize} bytes"
          end
        end
    end

    class SignedKeyRotatingCookieJar < AbstractCookieJar # :nodoc:
      include SerializedCookieJars

      def initialize(parent_jar)
        super

        secret = request.key_generator.generate_key(request.signed_cookie_salt)
        @verifier = ActiveSupport::MessageVerifier.new(secret, digest: signed_cookie_digest, serializer: SERIALIZER)

        request.cookies_rotations.signed.each do |(*secrets)|
          options = secrets.extract_options!
          @verifier.rotate(*secrets, serializer: SERIALIZER, **options)
        end
      end

      private
        def parse(name, signed_message, purpose: nil)
          rotated = false
          data = @verifier.verified(signed_message, purpose: purpose, on_rotation: -> { rotated = true })
          super(name, data, force_reserialize: rotated)
        end

        def commit(name, options)
          super
          options[:value] = @verifier.generate(options[:value], **cookie_metadata(name, options))
          check_for_overflow!(name, options)
        end
    end

    class EncryptedKeyRotatingCookieJar < AbstractCookieJar # :nodoc:
      include SerializedCookieJars

      def initialize(parent_jar)
        super

        if request.use_authenticated_cookie_encryption
          key_len = ActiveSupport::MessageEncryptor.key_len(encrypted_cookie_cipher)
          secret = request.key_generator.generate_key(request.authenticated_encrypted_cookie_salt, key_len)
          @encryptor = ActiveSupport::MessageEncryptor.new(secret, cipher: encrypted_cookie_cipher, serializer: SERIALIZER)
        else
          key_len = ActiveSupport::MessageEncryptor.key_len("aes-256-cbc")
          secret = request.key_generator.generate_key(request.encrypted_cookie_salt, key_len)
          sign_secret = request.key_generator.generate_key(request.encrypted_signed_cookie_salt)
          @encryptor = ActiveSupport::MessageEncryptor.new(secret, sign_secret, cipher: "aes-256-cbc", serializer: SERIALIZER)
        end

        request.cookies_rotations.encrypted.each do |(*secrets)|
          options = secrets.extract_options!
          @encryptor.rotate(*secrets, serializer: SERIALIZER, **options)
        end

        if upgrade_legacy_hmac_aes_cbc_cookies?
          legacy_cipher = "aes-256-cbc"
          secret = request.key_generator.generate_key(request.encrypted_cookie_salt, ActiveSupport::MessageEncryptor.key_len(legacy_cipher))
          sign_secret = request.key_generator.generate_key(request.encrypted_signed_cookie_salt)

          @encryptor.rotate(secret, sign_secret, cipher: legacy_cipher, digest: digest, serializer: SERIALIZER)
        elsif prepare_upgrade_legacy_hmac_aes_cbc_cookies?
          future_cipher = encrypted_cookie_cipher
          secret = request.key_generator.generate_key(request.authenticated_encrypted_cookie_salt, ActiveSupport::MessageEncryptor.key_len(future_cipher))

          @encryptor.rotate(secret, nil, cipher: future_cipher, serializer: SERIALIZER)
        end
      end

      private
        def parse(name, encrypted_message, purpose: nil)
          rotated = false
          data = @encryptor.decrypt_and_verify(encrypted_message, purpose: purpose, on_rotation: -> { rotated = true })
          super(name, data, force_reserialize: rotated)
        rescue ActiveSupport::MessageEncryptor::InvalidMessage, ActiveSupport::MessageVerifier::InvalidSignature
          nil
        end

        def commit(name, options)
          super
          options[:value] = @encryptor.encrypt_and_sign(options[:value], **cookie_metadata(name, options))
          check_for_overflow!(name, options)
        end
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      response = @app.call(env)

      if request.have_cookie_jar?
        cookie_jar = request.cookie_jar
        unless cookie_jar.committed?
          response = Rack::Response[*response]
          cookie_jar.write(response)
        end
      end

      response.to_a
    end
  end
end
