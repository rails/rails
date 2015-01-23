require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class TypesTest < ActiveRecord::TestCase
      def test_type_cast_boolean
        type = Type::Boolean.new
        assert type.type_cast_from_user('').nil?
        assert type.type_cast_from_user(nil).nil?

        assert type.type_cast_from_user(true)
        assert type.type_cast_from_user(1)
        assert type.type_cast_from_user('1')
        assert type.type_cast_from_user('t')
        assert type.type_cast_from_user('T')
        assert type.type_cast_from_user('true')
        assert type.type_cast_from_user('TRUE')
        assert type.type_cast_from_user('on')
        assert type.type_cast_from_user('ON')

        # explicitly check for false vs nil
        assert_equal false, type.type_cast_from_user(false)
        assert_equal false, type.type_cast_from_user(0)
        assert_equal false, type.type_cast_from_user('0')
        assert_equal false, type.type_cast_from_user('f')
        assert_equal false, type.type_cast_from_user('F')
        assert_equal false, type.type_cast_from_user('false')
        assert_equal false, type.type_cast_from_user('FALSE')
        assert_equal false, type.type_cast_from_user('off')
        assert_equal false, type.type_cast_from_user('OFF')
        assert_deprecated do
          assert_equal false, type.type_cast_from_user(' ')
          assert_equal false, type.type_cast_from_user("\u3000\r\n")
          assert_equal false, type.type_cast_from_user("\u0000")
          assert_equal false, type.type_cast_from_user('SOMETHING RANDOM')
        end
      end

      def test_type_cast_float
        type = Type::Float.new
        assert_equal 1.0, type.type_cast_from_user("1")
      end

      def test_changing_float
        type = Type::Float.new

        assert type.changed?(5.0, 5.0, '5wibble')
        assert_not type.changed?(5.0, 5.0, '5')
        assert_not type.changed?(5.0, 5.0, '5.0')
        assert_not type.changed?(nil, nil, nil)
      end

      def test_type_cast_binary
        type = Type::Binary.new
        assert_equal nil, type.type_cast_from_user(nil)
        assert_equal "1", type.type_cast_from_user("1")
        assert_equal 1, type.type_cast_from_user(1)
      end

      def test_type_cast_time
        type = Type::Time.new
        assert_equal nil, type.type_cast_from_user(nil)
        assert_equal nil, type.type_cast_from_user('')
        assert_equal nil, type.type_cast_from_user('ABC')

        time_string = Time.now.utc.strftime("%T")
        assert_equal time_string, type.type_cast_from_user(time_string).strftime("%T")
      end

      def test_type_cast_datetime_and_timestamp
        type = Type::DateTime.new
        assert_equal nil, type.type_cast_from_user(nil)
        assert_equal nil, type.type_cast_from_user('')
        assert_equal nil, type.type_cast_from_user('  ')
        assert_equal nil, type.type_cast_from_user('ABC')

        datetime_string = Time.now.utc.strftime("%FT%T")
        assert_equal datetime_string, type.type_cast_from_user(datetime_string).strftime("%FT%T")
      end

      def test_type_cast_date
        type = Type::Date.new
        assert_equal nil, type.type_cast_from_user(nil)
        assert_equal nil, type.type_cast_from_user('')
        assert_equal nil, type.type_cast_from_user(' ')
        assert_equal nil, type.type_cast_from_user('ABC')

        date_string = Time.now.utc.strftime("%F")
        assert_equal date_string, type.type_cast_from_user(date_string).strftime("%F")
      end

      def test_type_cast_duration_to_integer
        type = Type::Integer.new
        assert_equal 1800, type.type_cast_from_user(30.minutes)
        assert_equal 7200, type.type_cast_from_user(2.hours)
      end

      def test_string_to_time_with_timezone
        [:utc, :local].each do |zone|
          with_timezone_config default: zone do
            type = Type::DateTime.new
            assert_equal Time.utc(2013, 9, 4, 0, 0, 0), type.type_cast_from_user("Wed, 04 Sep 2013 03:00:00 EAT")
          end
        end
      end

      def test_type_equality
        assert_equal Type::Value.new, Type::Value.new
        assert_not_equal Type::Value.new, Type::Integer.new
        assert_not_equal Type::Value.new(precision: 1), Type::Value.new(precision: 2)
      end

      if current_adapter?(:SQLite3Adapter)
        def test_binary_encoding
          type = SQLite3Binary.new
          utf8_string = "a string".encode(Encoding::UTF_8)
          type_cast = type.type_cast_from_user(utf8_string)

          assert_equal Encoding::ASCII_8BIT, type_cast.encoding
        end
      end

      def test_attributes_which_are_invalid_for_database_can_still_be_reassigned
        type_which_cannot_go_to_the_database = Type::Value.new
        def type_which_cannot_go_to_the_database.type_cast_for_database(*)
          raise
        end
        klass = Class.new(ActiveRecord::Base) do
          self.table_name = 'posts'
          attribute :foo, type_which_cannot_go_to_the_database
        end
        model = klass.new

        model.foo = "foo"
        model.foo = "bar"

        assert_equal "bar", model.foo
      end
    end
  end
end
