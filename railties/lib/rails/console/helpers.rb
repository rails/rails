module Rails
  module ConsoleMethods
    # Gets the helper methods available to the controller.
    #
    # This method assumes an +ApplicationController+ exists, and it extends +ActionController::Base+
    def helper
      ApplicationController.helpers
    end

    # Gets a new instance of a controller object.
    #
    # This method assumes an +ApplicationController+ exists, and it extends +ActionController::Base+
    def controller
      @controller ||= ApplicationController.new
    end
  end
end
