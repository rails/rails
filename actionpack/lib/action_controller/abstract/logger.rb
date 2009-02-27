module AbstractController
  module Logger
    def self.included(klass)
      klass.cattr_accessor :logger
    end
  end
end