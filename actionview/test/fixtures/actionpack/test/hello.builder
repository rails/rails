xml.html do
  xml.p "Hello #{@name}"
  xml << render(file: "test/greeting")
end
