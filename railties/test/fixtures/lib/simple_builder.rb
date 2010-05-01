class AppBuilder
  def configru
    create_file "config.ru", <<-R.strip
run proc { |env| [200, { "Content-Type" => "text/html" }, ["Hello World"]] }
    R
  end
end