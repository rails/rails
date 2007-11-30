def tail(log_file)
  cursor = File.size(log_file)
  last_checked = Time.now
  tail_thread = Thread.new do
    File.open(log_file, 'r') do |f|
      loop do
        f.seek cursor
        if f.mtime > last_checked
          last_checked = f.mtime
          contents = f.read
          cursor += contents.length
          print contents
        end
        sleep 1
      end
    end
  end
  tail_thread
end

def start_debugger
  begin
    require_library_or_gem 'ruby-debug'
    Debugger.start
    Debugger.settings[:autoeval] = true if Debugger.respond_to?(:settings)
    puts "=> Debugger enabled"
  rescue Exception
    puts "You need to install ruby-debug to run the server in debugging mode. With gems, use 'gem install ruby-debug'"
    exit
  end
end