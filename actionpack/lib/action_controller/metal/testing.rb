module ActionController
  module Testing
    extend ActiveSupport::Concern

    # Behavior specific to functional tests
    module Functional # :nodoc:
      def recycle!
        @_url_options = nil
        self.formats = nil
        self.params = nil
      end
    end

    module ClassMethods
      def before_filters
        _process_action_callbacks.find_all{|x| x.kind == :before}.map(&:name)
      end
    end
  end
end
