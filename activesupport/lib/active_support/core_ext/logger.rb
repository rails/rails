# Adds the 'around_level' method to Logger.

class Logger
  def self.define_around_helper(level)
    module_eval <<-end_eval
      def around_#{level}(before_message, after_message, &block)
        self.#{level}(before_message)
        return_value = block.call(self)
        self.#{level}(after_message)
        return return_value
      end
    end_eval
  end
  [:debug, :info, :error, :fatal].each {|level| define_around_helper(level) }

end