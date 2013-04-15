require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/object/blank'
require 'active_support/key_generator'
require 'active_support/message_verifier'

module ActionDispatch
  class Request < Rack::Request
    def cookie_jar
      env['action_dispatch.cookies'] ||= Cookies::CookieJar.build(self)
    end
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
  #   # Assign an array of values to a cookie.
  #   cookies[:lat_lon] = [47.68, -122.37]
  #
  #   # Sets a cookie that expires in 1 hour.
  #   cookies[:login] = { value: "XJ-122", expires: 1.hour.from_now }
  #
  #   # Sets a signed cookie, which prevents users from tampering with its value.
  #   # The cookie is signed by your app's <tt>config.secret_key_base</tt> value.
  #   # It can be read using the signed method <tt>cookies.signed[:name]</tt>
  #   cookies.signed[:user_id] = current_user.id
  #
  #   # Sets a "permanent" cookie (which expires in 20 years from now).
  #   cookies.permanent[:login] = "XJ-122"
  #
  #   # You can also chain these methods:
  #   cookies.permanent.signed[:login] = "XJ-122"
  #
  # Examples of reading:
  #
  #   cookies[:user_name]    # => "david"
  #   cookies.size           # => 2
  #   cookies[:lat_lon]      # => [47.68, -122.37]
  #   cookies.signed[:login] # => "XJ-122"
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
  # * <tt>:value</tt> - The cookie's value or list of values (as an array).
  # * <tt>:path</tt> - The path for which this cookie applies. Defaults to the root
  #   of the application.
  # * <tt>:domain</tt> - The domain for which this cookie applies so you can
  #   restrict to the domain level. If you use a schema like www.example.com
  #   and want to share session with user.example.com set <tt>:domain</tt>
  #   to <tt>:all</tt>. Make sure to specify the <tt>:domain</tt> option with
  #   <tt>:all</tt> again when deleting cookies.
  #
  #     domain: nil  # Does not sets cookie domain. (default)
  #     domain: :all # Allow the cookie for the top most level
  #                       domain and subdomains.
  #
  # * <tt>:expires</tt> - The time at which this cookie expires, as a \Time object.
  # * <tt>:secure</tt> - Whether this cookie is a only transmitted to HTTPS servers.
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
        @permanent ||= PermanentCookieJar.new(self, @key_generator, @options)
      end

      # Returns a jar that'll automatically generate a signed representation of cookie value and verify it when reading from
      # the cookie again. This is useful for creating cookies with values that the user is not supposed to change. If a signed
      # cookie was tampered with by the user (or a 3rd party), nil will be returned.
      #
      # If +config.secret_key_base+ and +config.secret_token+ (deprecated) are both set,
      # legacy cookies signed with the old key generator will be transparently upgraded.
      #
      # This jar requires that you set a suitable secret for the verification on your app's +config.secret_key_base+.
      #
      # Example:
      #
      #   cookies.signed[:discount] = 45
      #   # => Set-Cookie: discount=BAhpMg==--2c1c6906c90a3bc4fd54a51ffb41dffa4bf6b5f7; path=/
      #
      #   cookies.signed[:discount] # => 45
      def signed
        @signed ||=
          if @options[:upgrade_legacy_signed_cookies]
            UpgradeLegacySignedCookieJar.new(self, @key_generator, @options)
          else
            SignedCookieJar.new(self, @key_generator, @options)
          end
      end

      # Returns a jar that'll automatically encrypt cookie values before sending them to the client and will decrypt them for read.
      # If the cookie was tampered with by the user (or a 3rd party), nil will be returned.
      #
      # If +config.secret_key_base+ and +config.secret_token+ (deprecated) are both set,
      # legacy cookies signed with the old key generator will be transparently upgraded.
      #
      # This jar requires that you set a suitable secret for the verification on your app's +config.secret_key_base+.
      #
      # Example:
      #
      #   cookies.encrypted[:discount] = 45
      #   # => Set-Cookie: discount=ZS9ZZ1R4cG1pcUJ1bm80anhQang3dz09LS1mbDZDSU5scGdOT3ltQ2dTdlhSdWpRPT0%3D--ab54663c9f4e3bc340c790d6d2b71e92f5b60315; path=/
      #
      #   cookies.encrypted[:discount] # => 45
      def encrypted
        @encrypted ||=
          if @options[:upgrade_legacy_signed_cookies]
            UpgradeLegacyEncryptedCookieJar.new(self, @key_generator, @options)
          else
            EncryptedCookieJar.new(self, @key_generator, @options)
          end
      end

      # Returns the +signed+ or +encrypted jar, preferring +encrypted+ if +secret_key_base+ is set.
      # Used by ActionDispatch::Session::CookieStore to avoid the need to introduce new cookie stores.
      def signed_or_encrypted
        @signed_or_encrypted ||=
          if @options[:secret_key_base].present?
            encrypted
          else
            signed
          end
      end
    end

    module VerifyAndUpgradeLegacySignedMessage
      def initialize(*args)
        super
        @legacy_verifier = ActiveSupport::MessageVerifier.new(@options[:secret_token])
      end

      def verify_and_upgrade_legacy_signed_message(name, signed_message)
        @legacy_verifier.verify(signed_message).tap do |value|
          self[name] = value
        end
      rescue ActiveSupport::MessageVerifier::InvalidSignature
        nil
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

      def self.options_for_env(env) #:nodoc:
        { signed_cookie_salt: env[SIGNED_COOKIE_SALT] || '',
          encrypted_cookie_salt: env[ENCRYPTED_COOKIE_SALT] || '',
          encrypted_signed_cookie_salt: env[ENCRYPTED_SIGNED_COOKIE_SALT] || '',
          secret_token: env[SECRET_TOKEN],
          secret_key_base: env[SECRET_KEY_BASE],
          upgrade_legacy_signed_cookies: env[SECRET_TOKEN].present? && env[SECRET_KEY_BASE].present?
        }
      end

      def self.build(request)
        env = request.env
        key_generator = env[GENERATOR_KEY]
        options = options_for_env env

        host = request.host
        secure = request.ssl?

        new(key_generator, host, secure, options).tap do |hash|
          hash.update(request.cookies)
        end
      end

      def initialize(key_generator, host = nil, secure = false, options = {})
        @key_generator = key_generator
        @set_cookies = {}
        @delete_cookies = {}
        @host = host
        @secure = secure
        @options = options
        @cookies = {}
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

      def handle_options(options) #:nodoc:
        options[:path] ||= "/"

        if options[:domain] == :all
          # if there is a provided tld length then we use it otherwise default domain regexp
          domain_regexp = options[:tld_length] ? /([^.]+\.?){#{options[:tld_length]}}$/ : DOMAIN_REGEXP

          # if host is not ip and matches domain regexp
          # (ip confirms to domain regexp so we explicitly check for ip)
          options[:domain] = if (@host !~ /^[\d.]+$/) && (@host =~ domain_regexp)
            ".#{$&}"
          end
        elsif options[:domain].is_a? Array
          # if host matches one of the supplied domains without a dot in front of it
          options[:domain] = options[:domain].find {|domain| @host.include? domain.sub(/^\./, '') }
        end
      end

      # Sets the cookie named +name+. The second argument may be the very cookie
      # value, or a hash of options as documented above.
      def []=(name, options)
        if options.is_a?(Hash)
          options.symbolize_keys!
          value = options[:value]
        else
          value = options
          options = { :value => value }
        end

        handle_options(options)

        if @cookies[name.to_s] != value or options[:expires]
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
        @cookies.each_key{ |k| delete(k, options) }
      end

      def write(headers)
        @set_cookies.each { |k, v| ::Rack::Utils.set_cookie_header!(headers, k, v) if write_cookie?(v) }
        @delete_cookies.each { |k, v| ::Rack::Utils.delete_cookie_header!(headers, k, v) }
      end

      def recycle! #:nodoc:
        @set_cookies.clear
        @delete_cookies.clear
      end

      mattr_accessor :always_write_cookie
      self.always_write_cookie = false

      private
        def write_cookie?(cookie)
          @secure || !cookie[:secure] || always_write_cookie
        end
    end

    class PermanentCookieJar #:nodoc:
      include ChainedCookieJars

      def initialize(parent_jar, key_generator, options = {})
        @parent_jar = parent_jar
        @key_generator = key_generator
        @options = options
      end

      def [](name)
        @parent_jar[name.to_s]
      end

      def []=(name, options)
        if options.is_a?(Hash)
          options.symbolize_keys!
        else
          options = { :value => options }
        end

        options[:expires] = 20.years.from_now
        @parent_jar[name] = options
      end
    end

    class SignedCookieJar #:nodoc:
      include ChainedCookieJars

      def initialize(parent_jar, key_generator, options = {})
        @parent_jar = parent_jar
        @options = options
        secret = key_generator.generate_key(@options[:signed_cookie_salt])
        @verifier   = ActiveSupport::MessageVerifier.new(secret)
      end

      def [](name)
        if signed_message = @parent_jar[name]
          verify(signed_message)
        end
      end

      def []=(name, options)
        if options.is_a?(Hash)
          options.symbolize_keys!
          options[:value] = @verifier.generate(options[:value])
        else
          options = { :value => @verifier.generate(options) }
        end

        raise CookieOverflow if options[:value].size > MAX_COOKIE_SIZE
        @parent_jar[name] = options
      end

      private
        def verify(signed_message)
          @verifier.verify(signed_message)
        rescue ActiveSupport::MessageVerifier::InvalidSignature
          nil
        end
    end

    # UpgradeLegacySignedCookieJar is used instead of SignedCookieJar if
    # config.secret_token and config.secret_key_base are both set. It reads
    # legacy cookies signed with the old dummy key generator and re-saves
    # them using the new key generator to provide a smooth upgrade path.
    class UpgradeLegacySignedCookieJar < SignedCookieJar #:nodoc:
      include VerifyAndUpgradeLegacySignedMessage

      def [](name)
        if signed_message = @parent_jar[name]
          verify(signed_message) || verify_and_upgrade_legacy_signed_message(name, signed_message)
        end
      end
    end

    class EncryptedCookieJar #:nodoc:
      include ChainedCookieJars

      def initialize(parent_jar, key_generator, options = {})
        if ActiveSupport::LegacyKeyGenerator === key_generator
          raise "You didn't set config.secret_key_base, which is required for this cookie jar. " +
            "Read the upgrade documentation to learn more about this new config option."
        end

        @parent_jar = parent_jar
        @options = options
        secret = key_generator.generate_key(@options[:encrypted_cookie_salt])
        sign_secret = key_generator.generate_key(@options[:encrypted_signed_cookie_salt])
        @encryptor = ActiveSupport::MessageEncryptor.new(secret, sign_secret)
      end

      def [](name)
        if encrypted_message = @parent_jar[name]
          decrypt_and_verify(encrypted_message)
        end
      end

      def []=(name, options)
        if options.is_a?(Hash)
          options.symbolize_keys!
        else
          options = { :value => options }
        end
        options[:value] = @encryptor.encrypt_and_sign(options[:value])

        raise CookieOverflow if options[:value].size > MAX_COOKIE_SIZE
        @parent_jar[name] = options
      end

      private
        def decrypt_and_verify(encrypted_message)
          @encryptor.decrypt_and_verify(encrypted_message)
        rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveSupport::MessageEncryptor::InvalidMessage
          nil
        end
    end

    # UpgradeLegacyEncryptedCookieJar is used by ActionDispatch::Session::CookieStore
    # instead of EncryptedCookieJar if config.secret_token and config.secret_key_base
    # are both set. It reads legacy cookies signed with the old dummy key generator and
    # encrypts and re-saves them using the new key generator to provide a smooth upgrade path.
    class UpgradeLegacyEncryptedCookieJar < EncryptedCookieJar #:nodoc:
      include VerifyAndUpgradeLegacySignedMessage

      def [](name)
        if encrypted_or_signed_message = @parent_jar[name]
          decrypt_and_verify(encrypted_or_signed_message) || verify_and_upgrade_legacy_signed_message(name, encrypted_or_signed_message)
        end
      end
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)

      if cookie_jar = env['action_dispatch.cookies']
        cookie_jar.write(headers)
        if headers[HTTP_HEADER].respond_to?(:join)
          headers[HTTP_HEADER] = headers[HTTP_HEADER].join("\n")
        end
      end

      [status, headers, body]
    end
  end
end
