# Rails Guides on the Kindle

## Synopsis

  1. Obtain `kindlegen` from the link below and put the binary in your path
  2. Run `ruby rails_guides.rb` to generate the guides and .mobi files
  3. Copy the .mobi files you wish to read to your Kindle
  
## Resources

  * [Kindle Publishing guidelines](http://kindlegen.s3.amazonaws.com/AmazonKindlePublishingGuidelines.pdf)
  * [KindleGen & Kindle Previewer](http://www.amazon.com/gp/feature.html?ie=UTF8&docId=1000234621) 
  
## TODO

### Minimum Viable Product

  * Create a manifest file, combining all of the guides into one 'book'
  * Create a HTML TOC that references each guide as a TOC item
  * Create a XML TOC as per the Kindle guidelines
  * Embed a cover image, as per the Kindle guidelines
  * Remove hacks from `rails_guides/generator.rb`, have Kindle generation as an option on `rails_guides.rb` instead.
  * Ensure sidebar / footnotes are rendered correctly
  
### Post release

  * Tweak heading styles (most docs use h3/h4/h5, which end up being smaller than the text under it)
  * Tweak table styles (smaller text? Many of the tables are unusable on a Kindle in portrait mode)
  * Have the HTML/XML TOC 'drill down' into the TOCs of the individual guides
  * `.epub` generation.
  