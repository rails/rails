module AbstractController
  module Logger
    setup do
      cattr_accessor :logger
    end
  end
end