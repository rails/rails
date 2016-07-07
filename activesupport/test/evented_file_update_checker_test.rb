# require 'abstract_unit'
# require 'pathname'
# require 'file_update_checker_shared_tests'
require 'tmpdir'
require 'listen'

if ENV['LISTEN'] == '1'
  20.times do
    Dir.mktmpdir do |tmpdir|
      begin
        Listen.to(tmpdir, &proc{}).start
        sleep 1
      ensure
        Listen.stop
      end
    end
  end
end

begin
  GC.disable if ENV['LISTEN'] == '1' && ENV['LISTEN_GC_FIX'] == '1'

  Dir.chdir("..") do
    i = 1

    Dir.glob("**/*") do |entry|
      break if i > 5000

      if File.file?(entry) && !File.zero?(entry)
        print "#{i}) Opening `#{entry}`: "
        File.open(entry, 'r') { |f| puts f.read(10).inspect }
      end

      i += 1
    end
  end
ensure
  GC.enable if ENV['LISTEN'] == '1' && ENV['LISTEN_GC_FIX'] == '1'
end
