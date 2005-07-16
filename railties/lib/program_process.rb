class ProgramProcess
  class << self
    def process_keywords(action, *keywords)
      processes = keywords.collect { |keyword| find_by_keyword(keyword) }.flatten

      if processes.empty?
        puts "Couldn't find any process matching: #{keywords.join(" or ")}"
      else
        processes.each do |process|
          puts "#{action.humanize}ing #{process}"
          process.send(action)
        end
      end      
    end

    def find_by_keyword(keyword)
      process_lines_with_keyword(keyword).split("\n").collect { |line|
        next if line.include?("inq") || line.include?("ps -ax") || line.include?("grep")
        pid, *command = line.split
        new(pid, command.join(" "))
      }.compact
    end

    private
      def process_lines_with_keyword(keyword)
        `ps -ax -o 'pid command' | grep #{keyword}`
      end
  end

  def initialize(pid, command)
    @pid, @command = pid, command
  end

  def find
  end

  def reload
    `kill -s HUP #{@pid}`
  end
  
  def restart
    kill
    `#{@command}`
  end

  def graceful_restart
    graceful_kill
    `#{@command}`
  end

  def graceful_kill
    `kill -s TERM #{@pid}`
  end

  def kill
    `kill -9 #{@pid}`
  end

  def to_s
    "[#{@pid}] #{@command}"
  end
end