# The Breakpoint library provides the convenience of
# being able to inspect and modify state, diagnose
# bugs all via IRB by simply setting breakpoints in
# your applications by the call of a method.
#
# This library was written and is supported by me,
# Florian Gross. I can be reached at flgr@ccan.de
# and enjoy getting feedback about my libraries.
#
# The whole library (including breakpoint_client.rb
# and binding_of_caller.rb) is licensed under the
# same license that Ruby uses. (Which is currently
# either the GNU General Public License or a custom
# one that allows for commercial usage.) If you for
# some good reason need to use this under another
# license please contact me.

require 'irb'
require File.dirname(__FILE__) + '/binding_of_caller' unless defined? Binding.of_caller
require 'drb'
require 'drb/acl'

module Breakpoint
  id = %q$Id: breakpoint.rb 92 2005-02-04 22:35:53Z flgr $
  Version = id.split(" ")[2].to_i

  extend self

  # This will pop up an interactive ruby session at a
  # pre-defined break point in a Ruby application. In
  # this session you can examine the environment of
  # the break point.
  #
  # You can get a list of variables in the context using
  # local_variables via +local_variables+. You can then
  # examine their values by typing their names.
  #
  # You can have a look at the call stack via +caller+.
  #
  # The source code around the location where the breakpoint
  # was executed can be examined via +source_lines+. Its
  # argument specifies how much lines of context to display.
  # The default amount of context is 5 lines. Note that
  # the call to +source_lines+ can raise an exception when
  # it isn't able to read in the source code.
  #
  # breakpoints can also return a value. They will execute
  # a supplied block for getting a default return value.
  # A custom value can be returned from the session by doing
  # +throw(:debug_return, value)+.
  #
  # You can also give names to break points which will be
  # used in the message that is displayed upon execution 
  # of them.
  #
  # Here's a sample of how breakpoints should be placed:
  #
  #   class Person
  #     def initialize(name, age)
  #       @name, @age = name, age
  #       breakpoint("Person#initialize")
  #     end
  #
  #     attr_reader :age
  #     def name
  #       breakpoint("Person#name") { @name }
  #     end
  #   end
  #
  #   person = Person.new("Random Person", 23)
  #   puts "Name: #{person.name}"
  #
  # And here is a sample debug session:
  #
  #   Executing break point "Person#initialize" at file.rb:4 in `initialize'
  #   irb(#<Person:0x292fbe8>):001:0> local_variables
  #   => ["name", "age", "_", "__"]
  #   irb(#<Person:0x292fbe8>):002:0> [name, age]
  #   => ["Random Person", 23]
  #   irb(#<Person:0x292fbe8>):003:0> [@name, @age]
  #   => ["Random Person", 23]
  #   irb(#<Person:0x292fbe8>):004:0> self
  #   => #<Person:0x292fbe8 @age=23, @name="Random Person">
  #   irb(#<Person:0x292fbe8>):005:0> @age += 1; self
  #   => #<Person:0x292fbe8 @age=24, @name="Random Person">
  #   irb(#<Person:0x292fbe8>):006:0> exit
  #   Executing break point "Person#name" at file.rb:9 in `name'
  #   irb(#<Person:0x292fbe8>):001:0> throw(:debug_return, "Overriden name")
  #   Name: Overriden name
  #
  # Breakpoint sessions will automatically have a few
  # convenience methods available. See Breakpoint::CommandBundle
  # for a list of them.
  #
  # Breakpoints can also be used remotely over sockets.
  # This is implemented by running part of the IRB session
  # in the application and part of it in a special client.
  # You have to call Breakpoint.activate_drb to enable
  # support for remote breakpoints and then run
  # breakpoint_client.rb which is distributed with this
  # library. See the documentation of Breakpoint.activate_drb
  # for details.
  def breakpoint(id = nil, context = nil, &block)
    callstack = caller
    callstack.slice!(0, 3) if callstack.first["breakpoint"]
    file, line, method = *callstack.first.match(/^(.+?):(\d+)(?::in `(.*?)')?/).captures

    message = "Executing break point " + (id ? "#{id.inspect} " : "") +
              "at #{file}:#{line}" + (method ? " in `#{method}'" : "")

    if context then
      return handle_breakpoint(context, message, file, line, &block)
    end

    Binding.of_caller do |binding_context|
      handle_breakpoint(binding_context, message, file, line, &block)
    end
  end

  module CommandBundle #:nodoc:
    # Proxy to a Breakpoint client. Lets you directly execute code
    # in the context of the client.
    class Client #:nodoc:
      def initialize(eval_handler) # :nodoc:
        eval_handler.untaint
        @eval_handler = eval_handler
      end

      instance_methods.each do |method|
        next if method[/^__.+__$/]
        undef_method method
      end

      # Executes the specified code at the client.
      def eval(code)
        @eval_handler.call(code)
      end

      # Will execute the specified statement at the client.
      def method_missing(method, *args, &block)
        if args.empty? and not block
          result = eval "#{method}"
        else
          # This is a bit ugly. The alternative would be using an
          # eval context instead of an eval handler for executing
          # the code at the client. The problem with that approach
          # is that we would have to handle special expressions
          # like "self", "nil" or constants ourself which is hard.
          remote = eval %{
            result = lambda { |block, *args| #{method}(*args, &block) }
            def result.call_with_block(*args, &block)
              call(block, *args)
            end
            result
          }
          remote.call_with_block(*args, &block)
        end

        return result
      end
    end

    # Returns the source code surrounding the location where the
    # breakpoint was issued.
    def source_lines(context = 5, return_line_numbers = false)
      lines = File.readlines(@__bp_file).map { |line| line.chomp }

      break_line = @__bp_line
      start_line = [break_line - context, 1].max
      end_line = break_line + context

      result = lines[(start_line - 1) .. (end_line - 1)]

      if return_line_numbers then
        return [start_line, break_line, result]
      else
        return result
      end
    end

    # Lets an object that will forward method calls to the breakpoint
    # client. This is useful for outputting longer things at the client
    # and so on. You can for example do these things:
    #
    #   client.puts "Hello" # outputs "Hello" at client console
    #   # outputs "Hello" into the file temp.txt at the client
    #   client.File.open("temp.txt", "w") { |f| f.puts "Hello" } 
    def client()
      if Breakpoint.use_drb? then
        sleep(0.5) until Breakpoint.drb_service.eval_handler
        Client.new(Breakpoint.drb_service.eval_handler)
      else
        Client.new(lambda { |code| eval(code, TOPLEVEL_BINDING) })
      end
    end
  end

  def handle_breakpoint(context, message, file = "", line = "", &block) # :nodoc:
    catch(:debug_return) do |value|
      eval(%{
        @__bp_file = #{file.inspect}
        @__bp_line = #{line}
        extend Breakpoint::CommandBundle
        extend DRbUndumped if self
      }, context) rescue nil

      if not use_drb? then
        puts message
        IRB.start(nil, IRB::WorkSpace.new(context))
      else
        @drb_service.add_breakpoint(context, message)
      end

      block.call if block
    end
  end

  # These exceptions will be raised on failed asserts
  # if Breakpoint.asserts_cause_exceptions is set to
  # true.
  class FailedAssertError < RuntimeError #:nodoc:
  end

  # This asserts that the block evaluates to true.
  # If it doesn't evaluate to true a breakpoint will
  # automatically be created at that execution point.
  #
  # You can disable assert checking in production
  # code by setting Breakpoint.optimize_asserts to
  # true. (It will still be enabled when Ruby is run
  # via the -d argument.)
  #
  # Example:
  #   person_name = "Foobar"
  #   assert { not person_name.nil? }
  #
  # Note: If you want to use this method from an
  # unit test, you will have to call it by its full
  # name, Breakpoint.assert.
  def assert(context = nil, &condition)
    return if Breakpoint.optimize_asserts and not $DEBUG
    return if yield

    callstack = caller
    callstack.slice!(0, 3) if callstack.first["assert"]
    file, line, method = *callstack.first.match(/^(.+?):(\d+)(?::in `(.*?)')?/).captures

    message = "Assert failed at #{file}:#{line}#{" in `#{method}'" if method}."

    if Breakpoint.asserts_cause_exceptions and not $DEBUG then
      raise(Breakpoint::FailedAssertError, message)
    end

    message += " Executing implicit breakpoint."

    if context then
      return handle_breakpoint(context, message, file, line)
    end

    Binding.of_caller do |context|
      handle_breakpoint(context, message, file, line)
    end
  end

  # Whether asserts should be ignored if not in debug mode.
  # Debug mode can be enabled by running ruby with the -d
  # switch or by setting $DEBUG to true.
  attr_accessor :optimize_asserts
  self.optimize_asserts = false

  # Whether an Exception should be raised on failed asserts
  # in non-$DEBUG code or not. By default this is disabled.
  attr_accessor :asserts_cause_exceptions
  self.asserts_cause_exceptions = false
  @use_drb = false

  attr_reader :drb_service # :nodoc:

  class DRbService # :nodoc:
    include DRbUndumped

    def initialize
      @handler = @eval_handler = @collision_handler = nil

      IRB.instance_eval { @CONF[:RC] = true }
      IRB.run_config
    end

    def collision
      sleep(0.5) until @collision_handler

      @collision_handler.untaint

      @collision_handler.call
    end

    def ping() end

    def add_breakpoint(context, message)
      workspace = IRB::WorkSpace.new(context)
      workspace.extend(DRbUndumped)

      sleep(0.5) until @handler

      @handler.untaint
      @handler.call(workspace, message)
    end

    attr_accessor :handler, :eval_handler, :collision_handler
  end

  # Will run Breakpoint in DRb mode. This will spawn a server
  # that can be attached to via the breakpoint-client command
  # whenever a breakpoint is executed. This is useful when you
  # are debugging CGI applications or other applications where
  # you can't access debug sessions via the standard input and
  # output of your application.
  #
  # You can specify an URI where the DRb server will run at.
  # This way you can specify the port the server runs on. The
  # default URI is druby://localhost:42531.
  #
  # Please note that breakpoints will be skipped silently in
  # case the DRb server can not spawned. (This can happen if
  # the port is already used by another instance of your
  # application on CGI or another application.)
  #
  # Also note that by default this will only allow access
  # from localhost. You can however specify a list of
  # allowed hosts or nil (to allow access from everywhere).
  # But that will still not protect you from somebody
  # reading the data as it goes through the net.
  #
  # A good approach for getting security and remote access
  # is setting up an SSH tunnel between the DRb service
  # and the client. This is usually done like this:
  #
  # $ ssh -L20000:127.0.0.1:20000 -R10000:127.0.0.1:10000 example.com
  # (This will connect port 20000 at the client side to port
  # 20000 at the server side, and port 10000 at the server
  # side to port 10000 at the client side.)
  #
  # After that do this on the server side: (the code being debugged)
  # Breakpoint.activate_drb("druby://127.0.0.1:20000", "localhost")
  #
  # And at the client side:
  # ruby breakpoint_client.rb -c druby://127.0.0.1:10000 -s druby://127.0.0.1:20000
  #
  # Running through such a SSH proxy will also let you use 
  # breakpoint.rb in case you are behind a firewall.
  #
  # Detailed information about running DRb through firewalls is
  # available at http://www.rubygarden.org/ruby?DrbTutorial
  def activate_drb(uri = nil, allowed_hosts = ['localhost', '127.0.0.1', '::1'],
    ignore_collisions = false)

    return false if @use_drb

    uri ||= 'druby://localhost:42531'

    if allowed_hosts then
      acl = ["deny", "all"]

      Array(allowed_hosts).each do |host|
        acl += ["allow", host]
      end

      DRb.install_acl(ACL.new(acl))
    end

    @use_drb = true
    @drb_service = DRbService.new
    did_collision = false
    begin
      @service = DRb.start_service(uri, @drb_service)
    rescue Errno::EADDRINUSE
      if ignore_collisions then
        nil
      else
        # The port is already occupied by another
        # Breakpoint service. We will try to tell
        # the old service that we want its port.
        # It will then forward that request to the
        # user and retry.
        unless did_collision then
          DRbObject.new(nil, uri).collision
          did_collision = true
        end
        sleep(10)
        retry
      end
    end

    return true
  end

  # Deactivates a running Breakpoint service.
  def deactivate_drb
    @service.stop_service unless @service.nil?
    @service = nil
    @use_drb = false
    @drb_service = nil
  end

  # Returns true when Breakpoints are used over DRb.
  # Breakpoint.activate_drb causes this to be true.
  def use_drb?
    @use_drb == true
  end
end

module IRB #:nodoc:
  class << self; remove_method :start; end
  def self.start(ap_path = nil, main_context = nil, workspace = nil)
    $0 = File::basename(ap_path, ".rb") if ap_path

    # suppress some warnings about redefined constants
    old_verbose, $VERBOSE = $VERBOSE, nil
    IRB.setup(ap_path)
    $VERBOSE = old_verbose

    if @CONF[:SCRIPT] then
      irb = Irb.new(main_context, @CONF[:SCRIPT])
    else
      irb = Irb.new(main_context)
    end

    if workspace then
      irb.context.workspace = workspace
    end

    @CONF[:IRB_RC].call(irb.context) if @CONF[:IRB_RC]
    @CONF[:MAIN_CONTEXT] = irb.context

    old_sigint = trap("SIGINT") do
      begin
        irb.signal_handle
      rescue RubyLex::TerminateLineInput
        # ignored
      end
    end
    
    catch(:IRB_EXIT) do
      irb.eval_input
    end
  ensure
    trap("SIGINT", old_sigint)
  end

  class << self
    alias :old_CurrentContext :CurrentContext
    remove_method :CurrentContext
  end
  def IRB.CurrentContext
    if old_CurrentContext.nil? and Breakpoint.use_drb? then
      result = Object.new
      def result.last_value; end
      return result
    else
      old_CurrentContext
    end
  end

  class << self
    alias :old_parse_opts :parse_opts
    remove_method :parse_opts
  end
  def IRB.parse_opts() end

  class Context #:nodoc:
    alias :old_evaluate :evaluate
    def evaluate(line, line_no)
      if line.chomp == "exit" then
        exit
      else
        old_evaluate(line, line_no)
      end
    end
  end

  class WorkSpace #:nodoc:
    alias :old_evaluate :evaluate

    def evaluate(*args)
      if Breakpoint.use_drb? then
        result = old_evaluate(*args)
        if args[0] != :no_proxy and
          not [true, false, nil].include?(result)
        then
          result.extend(DRbUndumped) rescue nil
        end
        return result
      else
        old_evaluate(*args)
      end
    end
  end

  module InputCompletor #:nodoc:
    def self.eval(code, context, *more)
      # Big hack, this assumes that InputCompletor
      # will only call eval() when it wants code
      # to be executed in the IRB context.
      IRB.conf[:MAIN_CONTEXT].workspace.evaluate(:no_proxy, code, *more)
    end
  end
end

module DRb # :nodoc:
  class DRbObject #:nodoc:
    undef :inspect if method_defined?(:inspect)
    undef :clone if method_defined?(:clone)
  end
end

# See Breakpoint.breakpoint
def breakpoint(id = nil, &block)
  Binding.of_caller do |context|
    Breakpoint.breakpoint(id, context, &block)
  end
end

# See Breakpoint.assert
def assert(&block)
  Binding.of_caller do |context|
    Breakpoint.assert(context, &block)
  end
end
