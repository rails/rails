require 'rack/auth/abstract/handler'
require 'rack/auth/digest/request'
require 'rack/auth/digest/params'
require 'rack/auth/digest/nonce'
require 'digest/md5'

module Rack
  module Auth
    module Digest
      # Rack::Auth::Digest::MD5 implements the MD5 algorithm version of
      # HTTP Digest Authentication, as per RFC 2617.
      #
      # Initialize with the [Rack] application that you want protecting,
      # and a block that looks up a plaintext password for a given username.
      #
      # +opaque+ needs to be set to a constant base64/hexadecimal string.
      #
      class MD5 < AbstractHandler

        attr_accessor :opaque

        attr_writer :passwords_hashed

        def initialize(*args)
          super
          @passwords_hashed = nil
        end

        def passwords_hashed?
          !!@passwords_hashed
        end

        def call(env)
          auth = Request.new(env)

          unless auth.provided?
            return unauthorized
          end

          if !auth.digest? || !auth.correct_uri? || !valid_qop?(auth)
            return bad_request
          end

          if valid?(auth)
            if auth.nonce.stale?
              return unauthorized(challenge(:stale => true))
            else
              env['REMOTE_USER'] = auth.username

              return @app.call(env)
            end
          end

          unauthorized
        end


        private

        QOP = 'auth'.freeze

        def params(hash = {})
          Params.new do |params|
            params['realm'] = realm
            params['nonce'] = Nonce.new.to_s
            params['opaque'] = H(opaque)
            params['qop'] = QOP

            hash.each { |k, v| params[k] = v }
          end
        end

        def challenge(hash = {})
          "Digest #{params(hash)}"
        end

        def valid?(auth)
          valid_opaque?(auth) && valid_nonce?(auth) && valid_digest?(auth)
        end

        def valid_qop?(auth)
          QOP == auth.qop
        end

        def valid_opaque?(auth)
          H(opaque) == auth.opaque
        end

        def valid_nonce?(auth)
          auth.nonce.valid?
        end

        def valid_digest?(auth)
          digest(auth, @authenticator.call(auth.username)) == auth.response
        end

        def md5(data)
          ::Digest::MD5.hexdigest(data)
        end

        alias :H :md5

        def KD(secret, data)
          H([secret, data] * ':')
        end

        def A1(auth, password)
          [ auth.username, auth.realm, password ] * ':'
        end

        def A2(auth)
          [ auth.method, auth.uri ] * ':'
        end

        def digest(auth, password)
          password_hash = passwords_hashed? ? password : H(A1(auth, password))

          KD(password_hash, [ auth.nonce, auth.nc, auth.cnonce, QOP, H(A2(auth)) ] * ':')
        end

      end
    end
  end
end
