module AbstractController
  module Logger
    extend ActiveSupport::DependencyModule

    included do
      cattr_accessor :logger
    end
  end
end