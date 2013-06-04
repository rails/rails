require 'abstract_unit'
require 'active_support/core_ext/logger'
require 'active_support/tagged_logging'

class TaggedLoggingTest < ActiveSupport::TestCase
  class MyLogger < ::Logger
    def flush(*)
      info "[FLUSHED]"
    end
  end

  # Formatter which displays the progname if it's not blank and the message.
  class MyFormatter < ::Logger::Formatter
    # This method is invoked when a log event occurs
    def call(severity, timestamp, progname, msg)
      "#{progname.blank? ? "" : "[#{progname}] "}#{String === msg ? msg : msg.inspect}\n"
    end
  end

  setup do
    @output = StringIO.new
    @logger = ActiveSupport::TaggedLogging.new(MyLogger.new(@output))
    @logger.formatter = MyFormatter.new
  end

  test "tagged once" do
    @logger.tagged("BCX") { @logger.info "Funky time" }
    assert_equal "[BCX] Funky time\n", @output.string
  end
  
  test "tagged twice" do
    @logger.tagged("BCX") { @logger.tagged("Jason") { @logger.info "Funky time" } }
    assert_equal "[BCX] [Jason] Funky time\n", @output.string
  end

  test "tagged thrice at once" do
    @logger.tagged("BCX", "Jason", "New") { @logger.info "Funky time" }
    assert_equal "[BCX] [Jason] [New] Funky time\n", @output.string
  end

  test "tagged are flattened" do
    @logger.tagged("BCX", %w(Jason New)) { @logger.info "Funky time" }
    assert_equal "[BCX] [Jason] [New] Funky time\n", @output.string
  end

  test "push and pop tags directly" do
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

  test "does not strip message content" do
    @logger.info "  Hello"
    assert_equal "  Hello\n", @output.string
  end

  test "provides access to the logger instance" do
    @logger.tagged("BCX") { |logger| logger.info "Funky time" }
    assert_equal "[BCX] Funky time\n", @output.string
  end

  test "tagged once with blank and nil" do
    @logger.tagged(nil, "", "New") { @logger.info "Funky time" }
    assert_equal "[New] Funky time\n", @output.string
  end

  test "keeps each tag in their own thread" do
    @logger.tagged("BCX") do
      Thread.new do
        @logger.tagged("OMG") { @logger.info "Cool story bro" }
      end.join
      @logger.info "Funky time"
    end
    assert_equal "[OMG] Cool story bro\n[BCX] Funky time\n", @output.string
  end

  test "cleans up the taggings on flush" do
    @logger.tagged("BCX") do
      Thread.new do
        @logger.tagged("OMG") do
          @logger.flush
          @logger.info "Cool story bro"
        end
      end.join
    end
    assert_equal "[FLUSHED]\nCool story bro\n", @output.string
  end

  test "mixed levels of tagging" do
    @logger.tagged("BCX") do
      @logger.tagged("Jason") { @logger.info "Funky time" }
      @logger.info "Junky time!"
    end

    assert_equal "[BCX] [Jason] Funky time\n[BCX] Junky time!\n", @output.string
  end

  test "silence" do
    assert_deprecated do
      assert_nothing_raised { @logger.silence {} }
    end
  end

  test "calls block" do
    @logger.tagged("BCX") do
      @logger.info { "Funky town" }
    end
    assert_equal "[BCX] Funky town\n", @output.string
  end

  test "displays progname if not blank" do
    @logger.progname = "PROG1"
    @logger.tagged("BCX") do
      @logger.info "Cool story bro"
    end

    @logger.tagged("BCX") do
      @logger.info("PROG2") { "Funky time" }
    end

    assert_equal "[PROG1] [BCX] Cool story bro\n[PROG2] [BCX] Funky time\n", @output.string
  end

  test "does not display progname if blank" do
    @logger.progname = nil
    @logger.tagged("BCX") { @logger.info "Funky time" }

    assert_equal "[BCX] Funky time\n", @output.string
  end

  test "evaluates the block if the severity is greater than or equal to logger's level" do
    message = ""
    @logger.level = ::Logger::INFO
    @logger.tagged("BCX") do
      @logger.info { message = "Funky time" }
    end

    assert_equal "Funky time", message
    assert_equal "[BCX] Funky time\n", @output.string
  end

  test "does not evaluate the block if the severity is less than logger's level" do
    message = ""
    @logger.level = ::Logger::ERROR
    @logger.tagged("BCX") do
      @logger.info { message = "Funky time" }
    end

    assert_blank message
    assert_blank @output.string
  end
end
