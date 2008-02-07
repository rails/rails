begin
  require 'base64'
rescue LoadError
end

module ActiveSupport
  if defined? ::Base64
    Base64 = ::Base64
  else
    # Ruby 1.9 doesn't provide base64, so we wrap this here
    module Base64

      def self.encode64(data)
        [data].pack("m")
      end

      def self.decode64(data)
        data.unpack("m").first
      end
    end
  end
end
