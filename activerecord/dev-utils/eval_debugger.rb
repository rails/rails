# Require this file to see the methods Active Record generates as they are added.
class Module #:nodoc:
  alias :old_module_eval :module_eval
  def module_eval(*args, &block)
    if args[0]
      puts  "----"
      print "module_eval in #{self.name}"
      print ": file #{args[1]}" if args[1]
      print " on line #{args[2]}" if args[2]
      puts  "\n#{args[0]}"
    end
    old_module_eval(*args, &block)
  end
end
