require File.dirname(__FILE__) + '/../scripts'

module Rails::Generator::Scripts
  class Update < Base
    mandatory_options :command => :update

    protected
      def banner
        "Usage: #{$0} [options] scaffold"
      end
  end
end
