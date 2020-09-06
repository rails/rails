# frozen_string_literal: true

require_relative 'abstract_unit'
require 'active_support/logger'
require 'active_support/tagged_logging'

class TaggedLoggingTest < ActiveSupport::TestCase
  class MyLogger < ::ActiveSupport::Logger
    def flush(*)
      info '[FLUSHED]'
    end
  end

  setup do
    @output = StringIO.new
    @logger = ActiveSupport::TaggedLogging.new(MyLogger.new(@output))
  end

  test 'sets logger.formatter if missing and extends it with a tagging API' do
    logger = Logger.new(StringIO.new)
    assert_nil logger.formatter

    other_logger = ActiveSupport::TaggedLogging.new(logger)
    assert_not_nil other_logger.formatter
    assert_respond_to other_logger.formatter, :tagged
  end

  test 'tagged once' do
    @logger.tagged('BCX') { @logger.info 'Funky time' }
    assert_equal "[BCX] Funky time\n", @output.string
  end

  test 'tagged twice' do
    @logger.tagged('BCX') { @logger.tagged('Jason') { @logger.info 'Funky time' } }
    assert_equal "[BCX] [Jason] Funky time\n", @output.string
  end

  test 'tagged thrice at once' do
    @logger.tagged('BCX', 'Jason', 'New') { @logger.info 'Funky time' }
    assert_equal "[BCX] [Jason] [New] Funky time\n", @output.string
  end

  test 'tagged are flattened' do
    @logger.tagged('BCX', %w(Jason New)) { @logger.info 'Funky time' }
    assert_equal "[BCX] [Jason] [New] Funky time\n", @output.string
  end

  test 'push and pop tags directly' do
    assert_equal %w(A B C), @logger.push_tags('A', ['B', '  ', ['C']])
    @logger.info 'a'
    assert_equal %w(C), @logger.pop_tags
    @logger.info 'b'
    assert_equal %w(B), @logger.pop_tags(1)
    @logger.info 'c'
    assert_equal [], @logger.clear_tags!
    @logger.info 'd'
    assert_equal "[A] [B] [C] a\n[A] [B] b\n[A] c\nd\n", @output.string
  end

  test 'does not strip message content' do
    @logger.info '  Hello'
    assert_equal "  Hello\n", @output.string
  end

  test 'provides access to the logger instance' do
    @logger.tagged('BCX') { |logger| logger.info 'Funky time' }
    assert_equal "[BCX] Funky time\n", @output.string
  end

  test 'tagged once with blank and nil' do
    @logger.tagged(nil, '', 'New') { @logger.info 'Funky time' }
    assert_equal "[New] Funky time\n", @output.string
  end

  test 'keeps each tag in their own thread' do
    @logger.tagged('BCX') do
      Thread.new do
        @logger.info 'Dull story'
        @logger.tagged('OMG') { @logger.info 'Cool story' }
      end.join
      @logger.info 'Funky time'
    end
    assert_equal "Dull story\n[OMG] Cool story\n[BCX] Funky time\n", @output.string
  end

  test 'keeps each tag in their own thread even when pushed directly' do
    Thread.new do
      @logger.push_tags('OMG')
      @logger.info 'Cool story'
    end.join
    @logger.info 'Funky time'
    assert_equal "[OMG] Cool story\nFunky time\n", @output.string
  end

  test 'keeps each tag in their own instance' do
    other_output = StringIO.new
    other_logger = ActiveSupport::TaggedLogging.new(MyLogger.new(other_output))
    @logger.tagged('OMG') do
      other_logger.tagged('BCX') do
        @logger.info 'Cool story'
        other_logger.info 'Funky time'
      end
    end
    assert_equal "[OMG] Cool story\n", @output.string
    assert_equal "[BCX] Funky time\n", other_output.string
  end

  test 'does not share the same formatter instance of the original logger' do
    other_logger = ActiveSupport::TaggedLogging.new(@logger)

    @logger.tagged('OMG') do
      other_logger.tagged('BCX') do
        @logger.info 'Cool story'
        other_logger.info 'Funky time'
      end
    end
    assert_equal "[OMG] Cool story\n[BCX] Funky time\n", @output.string
  end

  test 'cleans up the taggings on flush' do
    @logger.tagged('BCX') do
      Thread.new do
        @logger.tagged('OMG') do
          @logger.flush
          @logger.info 'Cool story'
        end
      end.join
    end
    assert_equal "[FLUSHED]\nCool story\n", @output.string
  end

  test 'mixed levels of tagging' do
    @logger.tagged('BCX') do
      @logger.tagged('Jason') { @logger.info 'Funky time' }
      @logger.info 'Junky time!'
    end

    assert_equal "[BCX] [Jason] Funky time\n[BCX] Junky time!\n", @output.string
  end
end

class TaggedLoggingWithoutBlockTest < ActiveSupport::TestCase
  setup do
    @output = StringIO.new
    @logger = ActiveSupport::TaggedLogging.new(Logger.new(@output))
  end

  test 'tagged once' do
    @logger.tagged('BCX').info 'Funky time'
    assert_equal "[BCX] Funky time\n", @output.string
  end

  test 'tagged twice' do
    @logger.tagged('BCX').tagged('Jason').info 'Funky time'
    assert_equal "[BCX] [Jason] Funky time\n", @output.string
  end

  test 'tagged thrice at once' do
    @logger.tagged('BCX', 'Jason', 'New').info 'Funky time'
    assert_equal "[BCX] [Jason] [New] Funky time\n", @output.string
  end

  test 'tagged are flattened' do
    @logger.tagged('BCX', %w(Jason New)).info 'Funky time'
    assert_equal "[BCX] [Jason] [New] Funky time\n", @output.string
  end

  test 'tagged once with blank and nil' do
    @logger.tagged(nil, '', 'New').info 'Funky time'
    assert_equal "[New] Funky time\n", @output.string
  end

  test 'shares tags across threads' do
    logger = @logger.tagged('BCX')

    Thread.new do
      logger.info 'Dull story'
      logger.tagged('OMG').info 'Cool story'
    end.join

    logger.info 'Funky time'

    assert_equal "[BCX] Dull story\n[BCX] [OMG] Cool story\n[BCX] Funky time\n", @output.string
  end

  test 'keeps each tag in their own instance' do
    other_output = StringIO.new
    other_logger = ActiveSupport::TaggedLogging.new(Logger.new(other_output))

    tagged_logger = @logger.tagged('OMG')
    other_tagged_logger = other_logger.tagged('BCX')
    tagged_logger.info 'Cool story'
    other_tagged_logger.info 'Funky time'

    assert_equal "[OMG] Cool story\n", @output.string
    assert_equal "[BCX] Funky time\n", other_output.string
  end

  test 'does not share the same formatter instance of the original logger' do
    other_logger = ActiveSupport::TaggedLogging.new(@logger)

    tagged_logger = @logger.tagged('OMG')
    other_tagged_logger = other_logger.tagged('BCX')
    tagged_logger.info 'Cool story'
    other_tagged_logger.info 'Funky time'

    assert_equal "[OMG] Cool story\n[BCX] Funky time\n", @output.string
  end

  test 'mixed levels of tagging' do
    logger = @logger.tagged('BCX')
    logger.tagged('Jason').info 'Funky time'
    logger.info 'Junky time!'

    assert_equal "[BCX] [Jason] Funky time\n[BCX] Junky time!\n", @output.string
  end
end
