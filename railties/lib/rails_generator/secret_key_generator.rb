# A class for creating random secret keys. This class will do its best to create a
# random secret key that's as secure as possible, using whatever methods are
# available on the current platform. For example:
#
#   generator = Rails::SecretKeyGenerator("some unique identifier, such as the application name")
#   generator.generate_secret     # => "f3f1be90053fa851... (some long string)"

module Rails
  class SecretKeyGenerator
    GENERATORS = [ :secure_random, :win32_api, :urandom, :openssl, :prng ].freeze

    def initialize(identifier)
      @identifier = identifier
    end

    # Generate a random secret key with the best possible method available on
    # the current platform.
    def generate_secret
      generator = GENERATORS.find do |g|
        self.class.send("supports_#{g}?")
      end
      send("generate_secret_with_#{generator}")
    end

    # Generate a random secret key by using the Win32 API. Raises LoadError
    # if the current platform cannot make use of the Win32 API. Raises
    # SystemCallError if some other error occured.
    def generate_secret_with_win32_api
      # Following code is based on David Garamond's GUID library for Ruby.
      require 'Win32API'

      crypt_acquire_context = Win32API.new("advapi32", "CryptAcquireContext",
                                           'PPPII', 'L')
      crypt_gen_random = Win32API.new("advapi32", "CryptGenRandom",
                                      'LIP', 'L')
      crypt_release_context = Win32API.new("advapi32", "CryptReleaseContext",
                                         'LI', 'L')
      prov_rsa_full       = 1
      crypt_verifycontext = 0xF0000000

      hProvStr = " " * 4
      if crypt_acquire_context.call(hProvStr, nil, nil, prov_rsa_full,
                                    crypt_verifycontext) == 0
        raise SystemCallError, "CryptAcquireContext failed: #{lastWin32ErrorMessage}"
      end
      hProv, = hProvStr.unpack('L')
      bytes = " " * 64
      if crypt_gen_random.call(hProv, bytes.size, bytes) == 0
        raise SystemCallError, "CryptGenRandom failed: #{lastWin32ErrorMessage}"
      end
      if crypt_release_context.call(hProv, 0) == 0
        raise SystemCallError, "CryptReleaseContext failed: #{lastWin32ErrorMessage}"
      end
      bytes.unpack("H*")[0]
    end

    # Generate a random secret key with Ruby 1.9's SecureRandom module.
    # Raises LoadError if the current Ruby version does not support
    # SecureRandom.
    def generate_secret_with_secure_random
      require 'securerandom'
      return SecureRandom.hex(64)
    end

    # Generate a random secret key with OpenSSL. If OpenSSL is not
    # already loaded, then this method will attempt to load it.
    # LoadError will be raised if that fails.
    def generate_secret_with_openssl
      require 'openssl'
      if !File.exist?("/dev/urandom")
        # OpenSSL transparently seeds the random number generator with
        # data from /dev/urandom. On platforms where that is not
        # available, such as Windows, we have to provide OpenSSL with
        # our own seed. Unfortunately there's no way to provide a
        # secure seed without OS support, so we'll have to do with
        # rand() and Time.now.usec().
        OpenSSL::Random.seed(rand(0).to_s + Time.now.usec.to_s)
      end
      data = OpenSSL::BN.rand(2048, -1, false).to_s
      return OpenSSL::Digest::SHA512.new(data).hexdigest
    end

    # Generate a random secret key with /dev/urandom.
    # Raises SystemCallError on failure.
    def generate_secret_with_urandom
      return File.read("/dev/urandom", 64).unpack("H*")[0]
    end

    # Generate a random secret key with Ruby's pseudo random number generator,
    # as well as some environment information.
    #
    # This is the least cryptographically secure way to generate a secret key,
    # and should be avoided whenever possible.
    def generate_secret_with_prng
      require 'digest/sha2'
      sha = Digest::SHA2.new(512)
      now = Time.now
      sha << now.to_s
      sha << String(now.usec)
      sha << String(rand(0))
      sha << String($$)
      sha << @identifier
      return sha.hexdigest
    end

    private
      def lastWin32ErrorMessage
        # Following code is based on David Garamond's GUID library for Ruby.
        get_last_error = Win32API.new("kernel32", "GetLastError", '', 'L')
        format_message = Win32API.new("kernel32", "FormatMessageA",
                                      'LPLLPLPPPPPPPP', 'L')
        format_message_ignore_inserts  = 0x00000200
        format_message_from_system     = 0x00001000

        code = get_last_error.call
        msg = "\0" * 1024
        len = format_message.call(format_message_ignore_inserts +
                                  format_message_from_system, 0,
                                  code, 0, msg, 1024, nil, nil,
                                  nil, nil, nil, nil, nil, nil)
        msg[0, len].tr("\r", '').chomp
      end

      def self.supports_secure_random?
        begin
          require 'securerandom'
          true
        rescue LoadError
          false
        end
      end

      def self.supports_win32_api?
        return false unless RUBY_PLATFORM =~ /(:?mswin|mingw)/
        begin
          require 'Win32API'
          true
        rescue LoadError
          false
        end
      end

      def self.supports_urandom?
        File.exist?('/dev/urandom')
      end

      def self.supports_openssl?
        begin
          require 'openssl'
          true
        rescue LoadError
          false
        end
      end

      def self.supports_prng?
        true
      end
  end
end
