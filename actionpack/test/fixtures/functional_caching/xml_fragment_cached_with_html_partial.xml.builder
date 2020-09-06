cache do
  xml.title 'Hello!'
end

xml.body cdata_section(render('formatted_partial'))
