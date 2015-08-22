require 'base64'
require 'openssl'
require 'active_support/core_ext/hash/keys'

module ActiveSupport
  class MessageEncryptor
    class JWE # :nodoc:
      attr_reader :cipher

      def initialize(**options)
        @options = options
        @secret = @options[:secret]
        @alg = key_encryption_algorithm
        @cipher = encryption_algorithm
        @enc = CIPHER_ENC_PAIRS[@cipher]
        @serializer = @options[:serializer] || Marshal
      end

      def encrypt(value)
        protected_header = @serializer.dump header

        cipher = new_cipher
        cipher.encrypt

        mac_key, cipher.key = derive_mac_and_enc_key(content_encryption_key)
        cipher.iv = iv = cipher.random_iv
        auth_data = encode(protected_header)
        if gcm?
          cipher.auth_data = auth_data
          ciphertext = cipher.update(@serializer.dump value) + cipher.final
          auth_tag = cipher.auth_tag
        else
          ciphertext = cipher.update(@serializer.dump value) + cipher.final
          auth_data_length = [auth_data.length * 8].pack('Q>')
          mac_input = [auth_data, iv, ciphertext, auth_data_length].join
          mac = generate_digest(mac_input, mac_key)
          auth_tag = mac[0...(mac.length / 2)]
        end

        auth_data << '.' << [jwe_encrypted_key, iv, ciphertext, auth_tag].map { |a| encode a }.join('.')
      end

      def decrypt(encrypted_message)
        parts = encrypted_message.split('.')
        auth_data = parts.shift
        encrypted_key, iv, ciphertext, auth_tag = parts.map { |a| decode a }
        valid_header?(@serializer.load decode(auth_data))
        valid_key? encrypted_key

        cipher = new_cipher
        cipher.decrypt
        if gcm?
          cipher.key = decrypt_content_encryption_key
          cipher.iv = iv
          cipher.auth_tag = auth_tag
          cipher.auth_data = auth_data
        else
          mac_key, cipher.key = derive_mac_and_enc_key(decrypt_content_encryption_key)
          auth_data_length = [auth_data.length * 8].pack("Q>")
          mac_input = [auth_data, iv, ciphertext, auth_data_length].join
          raise InvalidMessage unless untampered?(auth_tag, mac_input, mac_key)
          cipher.iv = iv
        end

        @serializer.load(cipher.update(ciphertext) + cipher.final)
      rescue OpenSSLCipherError, TypeError, ArgumentError
        raise InvalidMessage
      end

      private
        CIPHER_ENC_PAIRS = { 'aes-256-gcm' => 'A256GCM', 'aes-128-gcm' => 'A128GCM', 'aes-256-cbc' => 'A256CBC-HS512', 'aes-128-cbc' => 'A128CBC-HS256' }

        def gcm?
          ['aes-128-gcm', 'aes-256-gcm'].include?(@cipher)
        end

        def valid_header?(head)
          raise InvalidMessage unless head.stringify_keys == header
        end

        def valid_key?(key)
          raise InvalidMessage unless key.empty?
        end

        def new_cipher
          OpenSSL::Cipher::Cipher.new @cipher
        end

        def encryption_algorithm
          (@options[:enc] || @options[:cipher]).tap do |enc_or_cipher|
            if enc_or_cipher.nil?
              return 'aes-256-cbc'
            elsif CIPHER_ENC_PAIRS.keys.include?(enc_or_cipher.to_s)
              return enc_or_cipher.to_s
            elsif CIPHER_ENC_PAIRS.values.include?(enc_or_cipher.to_s)
              return CIPHER_ENC_PAIRS.key(enc_or_cipher.to_s)
            else
              raise UnexpectedAlgorithm, 'Unknown Encryption Algorithm.'
            end
          end
        end

        def key_encryption_algorithm
          if @options[:alg].nil? || @options[:alg] == 'dir'
            'dir'
          else
            raise UnexpectedAlgorithm, 'Unknown Key Encryption Algorithm.'
          end
        end

        def jwe_encrypted_key
          ''
        end

        def content_encryption_key
          @secret
        end

        def decrypt_content_encryption_key
          @secret
        end

        def header
          @header ||= { 'typ' => 'JWT', 'alg' => @alg.to_s, 'enc' => @enc.to_s }.tap do |header|
            header['kid'] = @options[:kid] if @options[:kid]
          end
        end

        def digest
          "sha#{@enc.split(//).last(3).join}"
        end

        def derive_mac_and_enc_key(key)
          gcm? ? [:not_needed, key] : key.unpack("a#{key.length / 2}" * 2)
        end

        def untampered?(digest, data, mac_key)
          mac = generate_digest(data, mac_key)
          ActiveSupport::SecurityUtils.secure_compare digest, mac[0...(mac.length / 2)]
        end

        def generate_digest(data, mac_key)
          require 'openssl' unless defined?(OpenSSL)
          OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new(digest), mac_key, data)
        end

        def encode(data)
          Base64.urlsafe_encode64(data)
        end

        def decode(data)
          return if data.nil?
          Base64.urlsafe_decode64(data)
        end
    end
  end
end
