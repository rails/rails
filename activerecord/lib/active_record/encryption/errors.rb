module ActiveRecord
  module Encryption
    module Errors
      class Base < StandardError; end
      class Encoding < Base; end
      class Decryption < Base; end
      class Encryption < Base; end
      class Configuration < Base; end
      class ForbiddenClass < Base; end
      class EncryptedContentIntegrity < Base; end
    end
  end
end
