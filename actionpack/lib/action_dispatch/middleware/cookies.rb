require "active_support/core_ext/hash/keys"
require "active_support/key_generator"
require "active_support/message_verifier"
require "active_support/json"
require "rack/utils"

module ActionDispatch
  class Request
    def cookie_jar
      fetch_header("action_dispatch.cookies".freeze) do
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
      has_header? "action_dispatch.cookies".freeze
    end

    def cookie_jar=(jar)
      set_header "action_dispatch.cookies".freeze, jar
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
  #   cookies[:login] = { value: "XJ-122", expires: 1.hour.from_now }
  #
  #   # Sets a signed cookie, which prevents users from tampering with its value.
  #   # The cookie is signed by your app's `secrets.secret_key_base` value.
  #   # It can be read using the signed method `cookies.signed[:name]`
  #   cookies.signed[:user_id] = current_user.id
  #
  #   # Sets an encrypted cookie value before sending it to the client which
  #   # prevent users from reading and tampering with its value.
  #   # The cookie is signed by your app's `secrets.secret_key_base` value.
  #   # It can be read using the encrypted method `cookies.encrypted[:name]`
  #   cookies.encrypted[:discount] = 45
  #
  #   # Sets a "permanent" cookie (which expires in 20 years from now).
  #   cookies.permanent[:login] = "XJ-122"
  #
  #   # You can also chain these methods:
  #   cookies.permanent.signed[:login] = "XJ-122"
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
  #    expires: 1.year.from_now,
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
  #   For example, to share cookies between user1.lvh.me and user2.lvh.me, set <tt>:tld_length</tt> to 1.
  # * <tt>:expires</tt> - The time at which this cookie expires, as a \Time object.
  # * <tt>:secure</tt> - Whether this cookie is only transmitted to HTTPS servers.
  #   Default is +false+.
  # * <tt>:httponly</tt> - Whether this cookie is accessible via scripting or
  #   only HTTP. Defaults to +false+.
  class Cookies
    HTTP_HEADER   = "Set-Cookie".freeze
    GENERATOR_KEY = "action_dispatch.key_generator".freeze
    SIGNED_COOKIE_SALT = "action_dispatch.signed_cookie_salt".freeze
    ENCRYPTED_COOKIE_SALT = "action_dispatch.encrypted_cookie_salt".freeze
    ENCRYPTED_SIGNED_COOKIE_SALT = "action_dispatch.encrypted_signed_cookie_salt".freeze
    SECRET_TOKEN = "action_dispatch.secret_token".freeze
    SECRET_KEY_BASE = "action_dispatch.secret_key_base".freeze
    COOKIES_SERIALIZER = "action_dispatch.cookies_serializer".freeze
    COOKIES_DIGEST = "action_dispatch.cookies_digest".freeze

    # Cookies can typically store 4096 bytes.
    MAX_COOKIE_SIZE = 4096

    # Raised when storing more than 4K of session data.
    CookieOverflow = Class.new StandardError

    # Include in a cookie jar to allow chaining, e.g. cookies.permanent.signed
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
      # cookie was tampered with by the user (or a 3rd party), nil will be returned.
      #
      # If +secrets.secret_key_base+ and +secrets.secret_token+ (deprecated) are both set,
      # legacy cookies signed with the old key generator will be transparently upgraded.
      #
      # This jar requires that you set a suitable secret for the verification on your app's +secrets.secret_key_base+.
      #
      # Example:
      #
      #   cookies.signed[:discount] = 45
      #   # => Set-Cookie: discount=BAhpMg==--2c1c6906c90a3bc4fd54a51ffb41dffa4bf6b5f7; path=/
      #
      #   cookies.signed[:discount] # => 45
      def signed
        @signed ||=
          if upgrade_legacy_signed_cookies?
            UpgradeLegacySignedCookieJar.new(self)
          else
            SignedCookieJar.new(self)
          end
      end

      # Returns a jar that'll automatically encrypt cookie values before sending them to the client and will decrypt them for read.
      # If the cookie was tampered with by the user (or a 3rd party), nil will be returned.
      #
      # If +secrets.secret_key_base+ and +secrets.secret_token+ (deprecated) are both set,
      # legacy cookies signed with the old key generator will be transparently upgraded.
      #
      # This jar requires that you set a suitable secret for the verification on your app's +secrets.secret_key_base+.
      #
      # Example:
      #
      #   cookies.encrypted[:discount] = 45
      #   # => Set-Cookie: discount=ZS9ZZ1R4cG1pcUJ1bm80anhQang3dz09LS1mbDZDSU5scGdOT3ltQ2dTdlhSdWpRPT0%3D--ab54663c9f4e3bc340c790d6d2b71e92f5b60315; path=/
      #
      #   cookies.encrypted[:discount] # => 45
      def encrypted
        @encrypted ||=
          if upgrade_legacy_signed_cookies?
            UpgradeLegacyEncryptedCookieJar.new(self)
          else
            EncryptedCookieJar.new(self)
          end
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
    end

    # Passing the ActiveSupport::MessageEncryptor::NullSerializer downstream
    # to the Message{Encryptor,Verifier} allows us to handle the
    # (de)serialization step within the cookie jar, which gives us the
    # opportunity to detect and migrate legacy cookies.
    module VerifyAndUpgradeLegacySignedMessage # :nodoc:
      def initialize(*args)
        super
        @legacy_verifier = ActiveSupport::MessageVerifier.new(request.secret_token, serializer: ActiveSupport::MessageEncryptor::NullSerializer)
      end

      def verify_and_upgrade_legacy_signed_message(name, signed_message)
        deserialize(name, @legacy_verifier.verify(signed_message)).tap do |value|
          self[name] = { value: value }
        end
      rescue ActiveSupport::MessageVerifier::InvalidSignature
        nil
      end

      private
        def parse(name, signed_message)
          super || verify_and_upgrade_legacy_signed_message(name, signed_message)
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

      def handle_options(options) #:nodoc:
        options[:path] ||= "/"

        if options[:domain] == :all || options[:domain] == "all"
          # if there is a provided tld length then we use it otherwise default domain regexp
          domain_regexp = options[:tld_length] ? /([^.]+\.?){#{options[:tld_length]}}$/ : DOMAIN_REGEXP

          # if host is not ip and matches domain regexp
          # (ip confirms to domain regexp so we explicitly check for ip)
          options[:domain] = if (request.host !~ /^[\d.]+$/) && (request.host =~ domain_regexp)
            ".#{$&}"
          end
        elsif options[:domain].is_a? Array
          # if host matches one of the supplied domains without a dot in front of it
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

      # Removes all cookies on the client machine by calling <tt>delete</tt> for each cookie
      def clear(options = {})
        @cookies.each_key { |k| delete(k, options) }
      end

      def write(headers)
        if header = make_set_cookie_header(headers[HTTP_HEADER])
          headers[HTTP_HEADER] = header
        end
      end

      mattr_accessor :always_write_cookie
      self.always_write_cookie = false

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
      MARSHAL_SIGNATURE = "\x04\x08".freeze

      protected
        def needs_migration?(value)
          request.cookies_serializer == :hybrid && value.start_with?(MARSHAL_SIGNATURE)
        end

        def serialize(value)
          serializer.dump(value)
        end

        def deserialize(name, value)
          if value
            if needs_migration?(value)
              Marshal.load(value).tap do |v|
                self[name] = { value: v }
              end
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

        def key_generator
          request.key_generator
        end
    end

    class SignedCookieJar < AbstractCookieJar # :nodoc:
      include SerializedCookieJars

      def initialize(parent_jar)
        super
        secret = key_generator.generate_key(request.signed_cookie_salt)
        @verifier = ActiveSupport::MessageVerifier.new(secret, digest: digest, serializer: ActiveSupport::MessageEncryptor::NullSerializer)
      end

      private
        def parse(name, signed_message)
          deserialize name, @verifier.verified(signed_message)
        end

        def commit(options)
          options[:value] = @verifier.generate(serialize(options[:value]))

          raise CookieOverflow if options[:value].bytesize > MAX_COOKIE_SIZE
        end
    end

    # UpgradeLegacySignedCookieJar is used instead of SignedCookieJar if
    # secrets.secret_token and secrets.secret_key_base are both set. It reads
    # legacy cookies signed with the old dummy key generator and signs and
    # re-saves them using the new key generator to provide a smooth upgrade path.
    class UpgradeLegacySignedCookieJar < SignedCookieJar #:nodoc:
      include VerifyAndUpgradeLegacySignedMessage
    end

    class EncryptedCookieJar < AbstractCookieJar # :nodoc:
      include SerializedCookieJars

      def initialize(parent_jar)
        super

        if ActiveSupport::LegacyKeyGenerator === key_generator
          raise "You didn't set secrets.secret_key_base, which is required for this cookie jar. " +
            "Read the upgrade documentation to learn more about this new config option."
        end

        secret = key_generator.generate_key(request.encrypted_cookie_salt || "")[0, ActiveSupport::MessageEncryptor.key_len]
        sign_secret = key_generator.generate_key(request.encrypted_signed_cookie_salt || "")
        @encryptor = ActiveSupport::MessageEncryptor.new(secret, sign_secret, digest: digest, serializer: ActiveSupport::MessageEncryptor::NullSerializer)
      end

      private
        def parse(name, encrypted_message)
          deserialize name, @encryptor.decrypt_and_verify(encrypted_message)
        rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveSupport::MessageEncryptor::InvalidMessage
          nil
        end

        def commit(options)
          options[:value] = @encryptor.encrypt_and_sign(serialize(options[:value]))

          raise CookieOverflow if options[:value].bytesize > MAX_COOKIE_SIZE
        end
    end

    # UpgradeLegacyEncryptedCookieJar is used by ActionDispatch::Session::CookieStore
    # instead of EncryptedCookieJar if secrets.secret_token and secrets.secret_key_base
    # are both set. It reads legacy cookies signed with the old dummy key generator and
    # encrypts and re-saves them using the new key generator to provide a smooth upgrade path.
    class UpgradeLegacyEncryptedCookieJar < EncryptedCookieJar #:nodoc:
      include VerifyAndUpgradeLegacySignedMessage
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
