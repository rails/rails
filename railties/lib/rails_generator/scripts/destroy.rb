require File.dirname(__FILE__) + '/../scripts'

module Rails::Generator::Scripts
  class Destroy < Base
    mandatory_options :command => :destroy
  end
end
