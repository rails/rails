# frozen_string_literal: true

module ConstantizeTestHelpers
  ROOT_DIR  = File.realpath("#{__dir__}/autoloading_fixtures")
  AUTOLOADS = {
    "RaisesLoadError"     => "#{ROOT_DIR}/raises_load_error",
    "RaisesNameError"     => "#{ROOT_DIR}/raises_name_error",
    "RaisesNoMethodError" => "#{ROOT_DIR}/raises_no_method_error"
  }

  def with_autoloading_fixtures
    define_autoloads
    yield
  ensure
    remove_autoloads
  end

  def define_autoloads
    AUTOLOADS.each do |constant, realpath|
      Object.autoload(constant, realpath)
    end
  end

  def remove_autoloads
    AUTOLOADS.each do |constant, realpath|
      Object.send(:remove_const, constant) if Object.const_defined?(constant)
      $LOADED_FEATURES.delete(realpath)
    end
  end
end
