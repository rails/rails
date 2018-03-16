# frozen_string_literal: true

require "active_support/core_ext/hash/keys"
require "active_support/key_generator"
require "active_support/message_verifier"
require "active_support/json"
require "rack/utils"

module ActionDispatch
  class Request
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

    def secret_token
      get_header Cookies::SECRET_TOKEN
    end

    def secret_key_base
      get_header Cookies::SECRET_KEY_BASE
    end

    def cookies_serializer
      get_header Cookies::COOKIES_SERIALIZER
    end

    def cookies_digest
      get_header Cookies::COOKIES_DIGEST
    end

    def cookies_rotations
      get_header Cookies::COOKIES_ROTATIONS
    end

    # :startdoc:
  end

  # \Cookies are read and written through ActionController#cookies.
  #
  # The cookies being read are the ones received along with the request, the cookies
  # being written will be sent out with the response. Reading a cookie does not get
  # the cookie object itself back, just the value it holds.
  #
  # Examples of writing:
  #
  #   # Sets a simple session cookie.
  #   # This cookie will be deleted when the user's browser is closed.
  #   cookies[:user_name] = "david"
  #
  #   # Cookie values are String based. Other data types need to be serialized.
  #   cookies[:lat_lon] = JSON.generate([47.68, -122.37])
  #
  #   # Sets a cookie that expires in 1 hour.
  #   cookies[:login] = { value: "XJ-122", expires: 1.hour }
  #
  #   # Sets a cookie that expires at a specific time.
  #   cookies[:login] = { value: "XJ-122", expires: Time.utc(2020, 10, 15, 5) }
  #
  #   # Sets a signed cookie, which prevents users from tampering with its value.
  #   # It can be read using the signed method `cookies.signed[:name]`
  #   cookies.signed[:user_id] = current_user.id
  #
  #   # Sets an encrypted cookie value before sending it to the client which
  #   # prevent users from reading and tampering with its value.
  #   # It can be read using the encrypted method `cookies.encrypted[:name]`
  #   cookies.encrypted[:discount] = 45
  #
  #   # Sets a "permanent" cookie (which expires in 20 years from now).
  #   cookies.permanent[:login] = "XJ-122"
  #
  #   # You can also chain these methods:
  #   cookies.signed.permanent[:login] = "XJ-122"
  #
  # Examples of reading:
  #
  #   cookies[:user_name]           # => "david"
  #   cookies.size                  # => 2
  #   JSON.parse(cookies[:lat_lon]) # => [47.68, -122.37]
  #   cookies.signed[:login]        # => "XJ-122"
  #   cookies.encrypted[:discount]  # => 45
  #
  # Example for deleting:
  #
  #   cookies.delete :user_name
  #
  # Please note that if you specify a :domain when setting a cookie, you must also specify the domain when deleting the cookie:
  #
  #  cookies[:name] = {
  #    value: 'a yummy cookie',
  #    expires: 1.year,
  #    domain: 'domain.com'
  #  }
  #
  #  cookies.delete(:name, domain: 'domain.com')
  #
  # The option symbols for setting cookies are:
  #
  # * <tt>:value</tt> - The cookie's value.
  # * <tt>:path</tt> - The path for which this cookie applies. Defaults to the root
  #   of the application.
  # * <tt>:domain</tt> - The domain for which this cookie applies so you can
  #   restrict to the domain level. If you use a schema like www.example.com
  #   and want to share session with user.example.com set <tt>:domain</tt>
  #   to <tt>:all</tt>. Make sure to specify the <tt>:domain</tt> option with
  #   <tt>:all</tt> or <tt>Array</tt> again when deleting cookies.
  #
  #     domain: nil  # Does not set cookie domain. (default)
  #     domain: :all # Allow the cookie for the top most level
  #                  # domain and subdomains.
  #     domain: %w(.example.com .example.org) # Allow the cookie
  #                                           # for concrete domain names.
  #
  # * <tt>:tld_length</tt> - When using <tt>:domain => :all</tt>, this option can be used to explicitly
  #   set the TLD length when using a short (<= 3 character) domain that is being interpreted as part of a TLD.
  #   For example, to share cookies between user1.lvh.me and user2.lvh.me, set <tt>:tld_length</tt> to 2.
  # * <tt>:expires</tt> - The time at which this cookie expires, as a \Time or ActiveSupport::Duration object.
  # * <tt>:secure</tt> - Whether this cookie is only transmitted to HTTPS servers.
  #   Default is +false+.
  # * <tt>:httponly</tt> - Whether this cookie is accessible via scripting or
  #   only HTTP. Defaults to +false+.
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
    SECRET_TOKEN = "action_dispatch.secret_token"
    SECRET_KEY_BASE = "action_dispatch.secret_key_base"
    COOKIES_SERIALIZER = "action_dispatch.cookies_serializer"
    COOKIES_DIGEST = "action_dispatch.cookies_digest"
    COOKIES_ROTATIONS = "action_dispatch.cookies_rotations"

    # Cookies can typically store 4096 bytes.
    MAX_COOKIE_SIZE = 4096

    # Raised when storing more than 4K of session data.
    CookieOverflow = Class.new StandardError

    # Include in a cookie jar to allow chaining, e.g. cookies.permanent.signed.
    module ChainedCookieJars
      # Returns a jar that'll automatically set the assigned cookies to have an expiration date 20 years from now. Example:
      #
      #   cookies.permanent[:prefers_open_id] = true
      #   # => Set-Cookie: prefers_open_id=true; path=/; expires=Sun, 16-Dec-2029 03:24:16 GMT
      #
      # This jar is only meant for writing. You'll read permanent cookies through the regular accessor.
      #
      # This jar allows chaining with the signed jar as well, so you can set permanent, signed cookies. Examples:
      #
      #   cookies.permanent.signed[:remember_me] = current_user.id
      #   # => Set-Cookie: remember_me=BAhU--848956038e692d7046deab32b7131856ab20e14e; path=/; expires=Sun, 16-Dec-2029 03:24:16 GMT
      def permanent
        @permanent ||= PermanentCookieJar.new(self)
      end

      # Returns a jar that'll automatically generate a signed representation of cookie value and verify it when reading from
      # the cookie again. This is useful for creating cookies with values that the user is not supposed to change. If a signed
      # cookie was tampered with by the user (or a 3rd party), +nil+ will be returned.
      #
      # If +secret_key_base+ and +secrets.secret_token+ (deprecated) are both set,
      # legacy cookies signed with the old key generator will be transparently upgraded.
      #
      # This jar requires that you set a suitable secret for the verification on your app's +secret_key_base+.
      #
      # Example:
      #
      #   cookies.signed[:discount] = 45
      #   # => Set-Cookie: discount=BAhpMg==--2c1c6906c90a3bc4fd54a51ffb41dffa4bf6b5f7; path=/
      #
      #   cookies.signed[:discount] # => 45
      def signed
        @signed ||= SignedKeyRotatingCookieJar.new(self)
      end

      # Returns a jar that'll automatically encrypt cookie values before sending them to the client and will decrypt them for read.
      # If the cookie was tampered with by the user (or a 3rd party), +nil+ will be returned.
      #
      # If +secret_key_base+ and +secrets.secret_token+ (deprecated) are both set,
      # legacy cookies signed with the old key generator will be transparently upgraded.
      #
      # If +config.action_dispatch.encrypted_cookie_salt+ and +config.action_dispatch.encrypted_signed_cookie_salt+
      # are both set, legacy cookies encrypted with HMAC AES-256-CBC will be transparently upgraded.
      #
      # This jar requires that you set a suitable secret for the verification on your app's +secret_key_base+.
      #
      # Example:
      #
      #   cookies.encrypted[:discount] = 45
      #   # => Set-Cookie: discount=DIQ7fw==--K3n//8vvnSbGq9dA--7Xh91HfLpwzbj1czhBiwOg==; path=/
      #
      #   cookies.encrypted[:discount] # => 45
      def encrypted
        @encrypted ||= EncryptedKeyRotatingCookieJar.new(self)
      end

      # Returns the +signed+ or +encrypted+ jar, preferring +encrypted+ if +secret_key_base+ is set.
      # Used by ActionDispatch::Session::CookieStore to avoid the need to introduce new cookie stores.
      def signed_or_encrypted
        @signed_or_encrypted ||=
          if request.secret_key_base.present?
            encrypted
          else
            signed
          end
      end

      private

        def upgrade_legacy_signed_cookies?
          request.secret_token.present? && request.secret_key_base.present?
        end

        def upgrade_legacy_hmac_aes_cbc_cookies?
          request.secret_key_base.present? &&
            request.encrypted_signed_cookie_salt.present? &&
            request.encrypted_cookie_salt.present? &&
            request.use_authenticated_cookie_encryption
        end

        def encrypted_cookie_cipher
          request.encrypted_cookie_cipher || "aes-256-gcm"
        end

        def signed_cookie_digest
          request.signed_cookie_digest || "SHA1"
        end
    end

    class CookieJar #:nodoc:
      include Enumerable, ChainedCookieJars

      # This regular expression is used to split the levels of a domain.
      # The top level domain can be any string without a period or
      # **.**, ***.** style TLDs like co.uk or com.au
      #
      # www.example.co.uk gives:
      # $& => example.co.uk
      #
      # example.com gives:
      # $& => example.com
      #
      # lots.of.subdomains.example.local gives:
      # $& => example.local
      DOMAIN_REGEXP = /[^.]*\.([^.]*|..\...|...\...)$/

      def self.build(req, cookies)
        new(req).tap do |hash|
          hash.update(cookies)
        end
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

      # Returns the value of the cookie by +name+, or +nil+ if no such cookie exists.
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
        set_cookies = request_jar.reject { |k, _| @delete_cookies.key?(k) }

        @cookies.update set_cookies if set_cookies
      end

      def to_header
        @cookies.map { |k, v| "#{escape(k)}=#{escape(v)}" }.join "; "
      end

      def handle_options(options) # :nodoc:
        if options[:expires].respond_to?(:from_now)
          options[:expires] = options[:expires].from_now
        end

        options[:path] ||= "/"

        if options[:domain] == :all || options[:domain] == "all"
          # If there is a provided tld length then we use it otherwise default domain regexp.
          domain_regexp = options[:tld_length] ? /([^.]+\.?){#{options[:tld_length]}}$/ : DOMAIN_REGEXP

          # If host is not ip and matches domain regexp.
          # (ip confirms to domain regexp so we explicitly check for ip)
          options[:domain] = if (request.host !~ /^[\d.]+$/) && (request.host =~ domain_regexp)
            ".#{$&}"
          end
        elsif options[:domain].is_a? Array
          # If host matches one of the supplied domains without a dot in front of it.
          options[:domain] = options[:domain].find { |domain| request.host.include? domain.sub(/^\./, "") }
        end
      end

      # Sets the cookie named +name+. The second argument may be the cookie's
      # value or a hash of options as documented above.
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

      # Removes the cookie on the client machine by setting the value to an empty string
      # and the expiration date in the past. Like <tt>[]=</tt>, you can pass in
      # an options hash to delete cookies with extra data such as a <tt>:path</tt>.
      def delete(name, options = {})
        return unless @cookies.has_key? name.to_s

        options.symbolize_keys!
        handle_options(options)

        value = @cookies.delete(name.to_s)
        @delete_cookies[name.to_s] = options
        value
      end

      # Whether the given cookie is to be deleted by this CookieJar.
      # Like <tt>[]=</tt>, you can pass in an options hash to test if a
      # deletion applies to a specific <tt>:path</tt>, <tt>:domain</tt> etc.
      def deleted?(name, options = {})
        options.symbolize_keys!
        handle_options(options)
        @delete_cookies[name.to_s] == options
      end

      # Removes all cookies on the client machine by calling <tt>delete</tt> for each cookie.
      def clear(options = {})
        @cookies.each_key { |k| delete(k, options) }
      end

      def write(headers)
        if header = make_set_cookie_header(headers[HTTP_HEADER])
          headers[HTTP_HEADER] = header
        end
      end

      mattr_accessor :always_write_cookie, default: false

      private

        def escape(string)
          ::Rack::Utils.escape(string)
        end

        def make_set_cookie_header(header)
          header = @set_cookies.inject(header) { |m, (k, v)|
            if write_cookie?(v)
              ::Rack::Utils.add_cookie_to_header(m, k, v)
            else
              m
            end
          }
          @delete_cookies.inject(header) { |m, (k, v)|
            ::Rack::Utils.add_remove_cookie_to_header(m, k, v)
          }
        end

        def write_cookie?(cookie)
          request.ssl? || !cookie[:secure] || always_write_cookie
        end
    end

    class AbstractCookieJar # :nodoc:
      include ChainedCookieJars

      def initialize(parent_jar)
        @parent_jar = parent_jar
      end

      def [](name)
        if data = @parent_jar[name.to_s]
          parse name, data
        end
      end

      def []=(name, options)
        if options.is_a?(Hash)
          options.symbolize_keys!
        else
          options = { value: options }
        end

        commit(options)
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

        def parse(name, data); data; end
        def commit(options); end
    end

    class PermanentCookieJar < AbstractCookieJar # :nodoc:
      private
        def commit(options)
          options[:expires] = 20.years.from_now
        end
    end

    class JsonSerializer # :nodoc:
      def self.load(value)
        ActiveSupport::JSON.decode(value)
      end

      def self.dump(value)
        ActiveSupport::JSON.encode(value)
      end
    end

    module SerializedCookieJars # :nodoc:
      MARSHAL_SIGNATURE = "\x04\x08"
      SERIALIZER = ActiveSupport::MessageEncryptor::NullSerializer

      protected
        def needs_migration?(value)
          request.cookies_serializer == :hybrid && value.start_with?(MARSHAL_SIGNATURE)
        end

        def serialize(value)
          serializer.dump(value)
        end

        def deserialize(name)
          rotate = false
          value  = yield -> { rotate = true }

          if value
            case
            when needs_migration?(value)
              self[name] = Marshal.load(value)
            when rotate
              self[name] = serializer.load(value)
            else
              serializer.load(value)
            end
          end
        end

        def serializer
          serializer = request.cookies_serializer || :marshal
          case serializer
          when :marshal
            Marshal
          when :json, :hybrid
            JsonSerializer
          else
            serializer
          end
        end

        def digest
          request.cookies_digest || "SHA1"
        end
    end

    class SignedKeyRotatingCookieJar < AbstractCookieJar # :nodoc:
      include SerializedCookieJars

      def initialize(parent_jar)
        super

        secret = request.key_generator.generate_key(request.signed_cookie_salt)
        @verifier = ActiveSupport::MessageVerifier.new(secret, digest: signed_cookie_digest, serializer: SERIALIZER)

        request.cookies_rotations.signed.each do |*secrets, **options|
          @verifier.rotate(*secrets, serializer: SERIALIZER, **options)
        end

        if upgrade_legacy_signed_cookies?
          @verifier.rotate request.secret_token, serializer: SERIALIZER
        end
      end

      private
        def parse(name, signed_message)
          deserialize(name) do |rotate|
            @verifier.verified(signed_message, on_rotation: rotate)
          end
        end

        def commit(options)
          options[:value] = @verifier.generate(serialize(options[:value]), expiry_options(options))

          raise CookieOverflow if options[:value].bytesize > MAX_COOKIE_SIZE
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

        request.cookies_rotations.encrypted.each do |*secrets, **options|
          @encryptor.rotate(*secrets, serializer: SERIALIZER, **options)
        end

        if upgrade_legacy_hmac_aes_cbc_cookies?
          legacy_cipher = "aes-256-cbc"
          secret = request.key_generator.generate_key(request.encrypted_cookie_salt, ActiveSupport::MessageEncryptor.key_len(legacy_cipher))
          sign_secret = request.key_generator.generate_key(request.encrypted_signed_cookie_salt)

          @encryptor.rotate(secret, sign_secret, cipher: legacy_cipher, digest: digest, serializer: SERIALIZER)
        end

        if upgrade_legacy_signed_cookies?
          @legacy_verifier = ActiveSupport::MessageVerifier.new(request.secret_token, digest: digest, serializer: SERIALIZER)
        end
      end

      private
        def parse(name, encrypted_message)
          deserialize(name) do |rotate|
            @encryptor.decrypt_and_verify(encrypted_message, on_rotation: rotate)
          end
        rescue ActiveSupport::MessageEncryptor::InvalidMessage, ActiveSupport::MessageVerifier::InvalidSignature
          parse_legacy_signed_message(name, encrypted_message)
        end

        def commit(options)
          options[:value] = @encryptor.encrypt_and_sign(serialize(options[:value]), expiry_options(options))

          raise CookieOverflow if options[:value].bytesize > MAX_COOKIE_SIZE
        end

        def parse_legacy_signed_message(name, legacy_signed_message)
          if defined?(@legacy_verifier)
            deserialize(name) do |rotate|
              rotate.call

              @legacy_verifier.verified(legacy_signed_message)
            end
          end
        end
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new env

      status, headers, body = @app.call(env)

      if request.have_cookie_jar?
        cookie_jar = request.cookie_jar
        unless cookie_jar.committed?
          cookie_jar.write(headers)
          if headers[HTTP_HEADER].respond_to?(:join)
            headers[HTTP_HEADER] = headers[HTTP_HEADER].join("\n")
          end
        end
      end

      [status, headers, body]
    end
  end
end
