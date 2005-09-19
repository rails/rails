module TestingSandbox

  # This whole thing *could* be much simpler, but I don't think Tempfile,
  # popen and others exist on all platforms (like Windows).
  def execute_in_sandbox(code)
    test_name = "#{File.dirname(__FILE__)}/test.#{$$}.rb"
    res_name = "#{File.dirname(__FILE__)}/test.#{$$}.out"

    File.open(test_name, "w+") do |file|
      file.write(<<-CODE)
        $:.unshift "../lib"
        block = Proc.new do
          #{code}
        end
        print block.call
      CODE
    end

    system("ruby #{test_name} > #{res_name}") or raise "could not run test in sandbox"
    File.read(res_name)
  ensure
    File.delete(test_name) rescue nil
    File.delete(res_name) rescue nil
  end

end
