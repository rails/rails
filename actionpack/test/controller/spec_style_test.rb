require "abstract_unit"

class ApplicationController < ActionController::Base; end
class ModelsController      < ApplicationController;  end
module Admin
  class WidgetsController < ApplicationController; end
end

# ApplicationController
describe ApplicationController do
  describe "nested" do
    describe "even deeper" do
      it "exists" do
        assert_kind_of ApplicationController, @controller
      end
    end
  end
end

describe ApplicationController, :index do
  describe "nested" do
    describe "even deeper" do
      it "exists" do
        assert_kind_of ApplicationController, @controller
      end
    end
  end
end

describe ApplicationController, "unauthenticated user" do
  describe "nested" do
    describe "even deeper" do
      it "exists" do
        assert_kind_of ApplicationController, @controller
      end
    end
  end
end

describe "ApplicationControllerTest" do
  describe "nested" do
    describe "even deeper" do
      it "exists" do
        assert_kind_of ApplicationController, @controller
      end
    end
  end
end

describe "ApplicationControllerTest", :index do
  describe "nested" do
    describe "even deeper" do
      it "exists" do
        assert_kind_of ApplicationController, @controller
      end
    end
  end
end

describe "ApplicationControllerTest", "unauthenticated user" do
  describe "nested" do
    describe "even deeper" do
      it "exists" do
        assert_kind_of ApplicationController, @controller
      end
    end
  end
end

# ModelsController
describe ModelsController do
  describe "nested" do
    describe "even deeper" do
      it "exists" do
        assert_kind_of ModelsController, @controller
      end
    end
  end
end

describe ModelsController, :index do
  describe "nested" do
    describe "even deeper" do
      it "exists" do
        assert_kind_of ModelsController, @controller
      end
    end
  end
end

describe ModelsController, "unauthenticated user" do
  describe "nested" do
    describe "even deeper" do
      it "exists" do
        assert_kind_of ModelsController, @controller
      end
    end
  end
end

describe "ModelsControllerTest" do
  describe "nested" do
    describe "even deeper" do
      it "exists" do
        assert_kind_of ModelsController, @controller
      end
    end
  end
end

describe "ModelsControllerTest", :index do
  describe "nested" do
    describe "even deeper" do
      it "exists" do
        assert_kind_of ModelsController, @controller
      end
    end
  end
end

describe "ModelsControllerTest", "unauthenticated user" do
  describe "nested" do
    describe "even deeper" do
      it "exists" do
        assert_kind_of ModelsController, @controller
      end
    end
  end
end

# Nested Admin::WidgetsControllerTest
module Admin
  class WidgetsControllerTest < ActionController::TestCase
    test "exists" do
      assert_kind_of Admin::WidgetsController, @controller
    end
  end

  describe WidgetsController do
    describe "index" do
      it "respond successful" do
        assert_kind_of Admin::WidgetsController, @controller
      end
    end
  end

  describe WidgetsController, "unauthenticated users" do
    describe "index" do
      it "respond successful" do
        assert_kind_of Admin::WidgetsController, @controller
      end
    end
  end
end

class Admin::WidgetsControllerTest < ActionController::TestCase
  test "exists here too" do
    assert_kind_of Admin::WidgetsController, @controller
  end
end

describe Admin::WidgetsController do
  describe "index" do
    it "respond successful" do
      assert_kind_of Admin::WidgetsController, @controller
    end
  end
end

describe Admin::WidgetsController, "unauthenticated users" do
  describe "index" do
    it "respond successful" do
      assert_kind_of Admin::WidgetsController, @controller
    end
  end
end

describe "Admin::WidgetsController" do
  describe "index" do
    it "respond successful" do
      assert_kind_of Admin::WidgetsController, @controller
    end
  end
end

describe "Admin::WidgetsControllerTest" do
  describe "index" do
    it "respond successful" do
      assert_kind_of Admin::WidgetsController, @controller
    end
  end
end

describe "Admin::WidgetsController", "unauthenticated users" do
  describe "index" do
    it "respond successful" do
      assert_kind_of Admin::WidgetsController, @controller
    end
  end
end

describe "Admin::WidgetsControllerTest", "unauthenticated users" do
  describe "index" do
    it "respond successful" do
      assert_kind_of Admin::WidgetsController, @controller
    end
  end
end
