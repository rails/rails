require "abstract_unit"
require "active_support/core_ext/class/inheritable_class_instance_reader"

class InheritableClassInstanceReaderTest < ActiveSupport::TestCase
  class Foo
    def self.site=(site)
      @site = site
    end
    inheritable_class_instance_reader :site
  end
  
  class Bar < Foo
    self.site = "google.com"
  end
  class Baz < Bar
  end
  class Bleh < Baz
  end
  class Balin < Bar
    self.site = "foo.com"
  end
  test "get class instance attribute" do
    assert 'google.com', Bar.site
    assert 'google.com', Baz.site
    assert 'google.com', Bleh.site
    assert 'foo.com', Balin.site
  end
end
