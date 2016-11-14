module ActionCable
  module Channel
    module StreamsHandlers # :nodoc:
      extend ActiveSupport::Autoload

      eager_autoload do
        autoload :Base
        autoload :Custom
      end
    end
  end
end
