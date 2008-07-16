xml.html do
  xml.p "Hello #{@name}"
  xml << render("test/greeting")
end