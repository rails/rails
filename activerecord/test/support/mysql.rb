if defined?(Mysql)
  class Mysql
    class Error
      # This monkey patch fixes annoy warning with mysql-2.8.1.gem when executing testcases.
      def errno_with_fix_warnings
        silence_warnings { errno_without_fix_warnings }
      end
      alias_method_chain :errno, :fix_warnings
    end
  end
end
