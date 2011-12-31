require 'abstract_unit'

module ActionDispatch
  class FlashHashTest < ActiveSupport::TestCase
    def setup
      @hash = Flash::FlashHash.new
    end

    def test_set_get
      @hash[:foo] = 'zomg'
      assert_equal 'zomg', @hash[:foo]
    end

    def test_keys
      assert_equal [], @hash.keys

      @hash['foo'] = 'zomg'
      assert_equal ['foo'], @hash.keys

      @hash['bar'] = 'zomg'
      assert_equal ['foo', 'bar'].sort, @hash.keys.sort
    end

    def test_update
      @hash['foo'] = 'bar'
      @hash.update('foo' => 'baz', 'hello' => 'world')

      assert_equal 'baz', @hash['foo']
      assert_equal 'world', @hash['hello']
    end

    def test_delete
      @hash['foo'] = 'bar'
      @hash.delete 'foo'

      assert !@hash.key?('foo')
      assert_nil @hash['foo']
    end

    def test_to_hash
      @hash['foo'] = 'bar'
      assert_equal({'foo' => 'bar'}, @hash.to_hash)

      @hash.to_hash['zomg'] = 'aaron'
      assert !@hash.key?('zomg')
      assert_equal({'foo' => 'bar'}, @hash.to_hash)
    end

    def test_empty?
      assert @hash.empty?
      @hash['zomg'] = 'bears'
      assert !@hash.empty?
      @hash.clear
      assert @hash.empty?
    end

    def test_each
      @hash['hello'] = 'world'
      @hash['foo'] = 'bar'

      things = []
      @hash.each do |k,v|
        things << [k,v]
      end

      assert_equal([%w{ hello world }, %w{ foo bar }].sort, things.sort)
    end

    def test_replace
      @hash['hello'] = 'world'
      @hash.replace('omg' => 'aaron')
      assert_equal({'omg' => 'aaron'}, @hash.to_hash)
    end

    def test_discard_no_args
      @hash['hello'] = 'world'
      @hash.discard

      @hash.sweep
      assert_equal({}, @hash.to_hash)
    end

    def test_discard_one_arg
      @hash['hello'] = 'world'
      @hash['omg']   = 'world'
      @hash.discard 'hello'

      @hash.sweep
      assert_equal({'omg' => 'world'}, @hash.to_hash)
    end

    def test_keep_sweep
      @hash['hello'] = 'world'

      @hash.sweep
      assert_equal({'hello' => 'world'}, @hash.to_hash)
    end

    def test_update_sweep
      @hash['hello'] = 'world'
      @hash.update({'hi' => 'mom'})

      @hash.sweep
      assert_equal({'hello' => 'world', 'hi' => 'mom'}, @hash.to_hash)
    end

    def test_update_delete_sweep
      @hash['hello'] = 'world'
      @hash.delete 'hello'
      @hash.update({'hello' => 'mom'})

      @hash.sweep
      assert_equal({'hello' => 'mom'}, @hash.to_hash)
    end

    def test_delete_sweep
      @hash['hello'] = 'world'
      @hash['hi']    = 'mom'
      @hash.delete 'hi'

      @hash.sweep
      assert_equal({'hello' => 'world'}, @hash.to_hash)
    end

    def test_clear_sweep
      @hash['hello'] = 'world'
      @hash.clear

      @hash.sweep
      assert_equal({}, @hash.to_hash)
    end

    def test_replace_sweep
      @hash['hello'] = 'world'
      @hash.replace({'hi' => 'mom'})

      @hash.sweep
      assert_equal({'hi' => 'mom'}, @hash.to_hash)
    end

    def test_discard_then_add
      @hash['hello'] = 'world'
      @hash['omg']   = 'world'
      @hash.discard 'hello'
      @hash['hello'] = 'world'

      @hash.sweep
      assert_equal({'omg' => 'world', 'hello' => 'world'}, @hash.to_hash)
    end

    def test_keep_all_sweep
      @hash['hello'] = 'world'
      @hash['omg']   = 'world'
      @hash.discard 'hello'
      @hash.keep

      @hash.sweep
      assert_equal({'omg' => 'world', 'hello' => 'world'}, @hash.to_hash)
    end

    def test_double_sweep
      @hash['hello'] = 'world'
      @hash.sweep

      assert_equal({'hello' => 'world'}, @hash.to_hash)

      @hash.sweep
      assert_equal({}, @hash.to_hash)
    end
  end
end
