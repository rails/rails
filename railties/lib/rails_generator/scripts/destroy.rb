require File.dirname(__FILE__) + '/../scripts'

module Rails::Generator::Scripts
  class Destroy < Base
    mandatory_options :command => :destroy

    protected
      def add_options!(opt)
      end
  end
end
