module Rails
  module ConsoleMethods
    def helper
      @helper ||= ApplicationController.helpers
    end

    def controller
      @controller ||= ApplicationController.new
    end
  end
end
