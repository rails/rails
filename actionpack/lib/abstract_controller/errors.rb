module AbstractController
  class AbstractControllerError < StandardError #:nodoc:
  end

  class ActionNotFound < AbstractControllerError #:nodoc:
  end

  class DoubleRenderError < AbstractControllerError #:nondoc:
    DEFAULT_MESSAGE = "Render and/or redirect were called multiple times in this action. Please note that you may only call render OR redirect, and at most once per action. Also note that neither redirect nor render terminate execution of the action, so if you want to exit an action after redirecting, you need to do something like \"redirect_to(...) and return\"."

    def initialize(message = nil)
      super(message || DEFAULT_MESSAGE)
    end
  end

  class UnsupportedOperationError < AbstractControllerError #:nodoc:
    def initialize
      super "Unsupported render operation. BasicRendering supports only :text and :nothing options. If you would like to use templates and layouts, you need to include ActionView gem."
    end
  end

  class NoRenderError < AbstractControllerError #:nodoc:
    def initialize
      super "BasicRendering requires controller action to invoke `render` method explicitly, with :text or :nothing option. If you would like to use templates and layouts, you need to include ActionView gem."
    end
  end
end
