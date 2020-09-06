xml.html do
  xml.p "Hello #{@name}"
  xml << render(template: 'test/greeting')
end
