$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../lib"
RAILS_ROOT = File.dirname(__FILE__)

require File.dirname(__FILE__) + '/../../activerecord/lib/active_record/support/inflector'
require 'rails_generator'
require 'test/unit'

# Railties test directory has RAILS_ROOT/generators instead of the expected
# RAILS_ROOT/script/generators, so override it manually.
old_verbose, $VERBOSE = $VERBOSE, nil
Rails::Generator.const_set(:CONTRIB_ROOT, "#{RAILS_ROOT}/generators")
$VERBOSE = old_verbose


class RailsGeneratorTest < Test::Unit::TestCase
  BUILTINS = %w(controller mailer model scaffold)

  def test_instance_builtins
    BUILTINS.each do |name|
      object = nil
      assert_nothing_raised { object = Rails::Generator.instance(name, ['foo']) }
      assert_not_nil object
      assert_match /#{name.capitalize}Generator/, object.class.name 
      assert_respond_to object, :generate
    end
  end

  def test_instance_without_rails_root
    old_verbose, $VERBOSE = $VERBOSE, nil
    old_rails_root = Object.const_get(:RAILS_ROOT)
    begin
      Object.const_set(:RAILS_ROOT, nil)
      assert_raise(Rails::Generator::GeneratorError) {
        Rails::Generator.instance('model', ['name'])
      }
    ensure
      Object.const_set(:RAILS_ROOT, old_rails_root)
      $VERBOSE = old_verbose
    end
  end

  def test_instance_not_found
    assert_raise(Rails::Generator::GeneratorError) {
      Rails::Generator.instance('foobar')
    }
  end

  def test_instance_missing_templates
    assert_raise(Rails::Generator::GeneratorError) {
      Rails::Generator.instance('missing_templates')
    }
  end

  def test_instance_missing_generator
    assert_raise(Rails::Generator::GeneratorError) {
      Rails::Generator.instance('missing_generator')
    }
  end

  def test_instance_missing_class
    assert_raise(Rails::Generator::GeneratorError) {
      Rails::Generator.instance('missing_class')
    }
  end

  def test_builtin_generators
    assert_nothing_raised {
      assert_equal [], Rails::Generator.builtin_generators - BUILTINS
    }
  end

  def test_generator_name
    assert_equal 'model', Rails::Generator.instance('model', ['name']).class.generator_name
  end

  def test_generator_usage
    assert_raise(Rails::Generator::UsageError) {
      assert_equal 'model', Rails::Generator.instance('model')
    }
  end

  def test_generator_vars
    model = Rails::Generator.instance('model', ['model'])
    assert_equal "#{Rails::Generator::BUILTIN_ROOT}/model/templates", model.template_root
    assert_equal RAILS_ROOT, model.destination_root
    assert_equal 'Model', model.class_name
    assert_equal 'model', model.singular_name
    assert_equal 'models', model.plural_name
    assert_equal model.singular_name, model.file_name
    assert_equal model.plural_name, model.table_name
    assert_equal [], model.args
  end

  def test_generator_generator
    assert_nothing_raised {
      model = Rails::Generator.instance('model', ['name'])
      mailer = model.send(:generator, 'mailer')
      assert_equal 'mailer', mailer.class.generator_name
    }
  end
end
