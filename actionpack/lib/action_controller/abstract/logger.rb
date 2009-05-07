module AbstractController
  module Logger
    extend ActiveSupport::DependencyModule

    setup do
      cattr_accessor :logger
    end
  end
end