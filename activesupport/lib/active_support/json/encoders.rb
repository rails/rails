module ActiveSupport
  module JSON #:nodoc:
    module Encoders
      mattr_accessor :encoders
      @@encoders = {}

      class << self        
        def define_encoder(klass, &block)
          encoders[klass] = block
        end
        
        def [](klass)
          klass.ancestors.each do |k|
            encoder = encoders[k]
            return encoder if encoder
          end
        end
      end
    end
  end
end

Dir[File.dirname(__FILE__) + '/encoders/*.rb'].each do |file|
  require file[0..-4]
end
