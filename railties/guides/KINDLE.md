# Rails Guides on the Kindle

## Synopsis

  1. Obtain `kindlegen` from the link below and put the binary in your path
  2. Run `KINDLE=1 ruby rails_guides.rb` to generate the guides
  3. Run `kindlegen output/kindle/rails_guides.opf` to generate `output/rails_guides.mobi`
  3. Copy `output/kindle/rails_guides.mobi` to your Kindle
  
## Resources

  * [Kindle Publishing guidelines](http://kindlegen.s3.amazonaws.com/AmazonKindlePublishingGuidelines.pdf)
  * [KindleGen & Kindle Previewer](http://www.amazon.com/gp/feature.html?ie=UTF8&docId=1000234621) 
  
## TODO

### Minimum Viable Product

  * Ensure sidebar / footnotes are rendered correctly
  
### Post release

  * Integrate generated Kindle document in to published HTML guides
  * Tweak heading styles (most docs use h3/h4/h5, which end up being smaller than the text under it)
  * Tweak table styles (smaller text? Many of the tables are unusable on a Kindle in portrait mode)
  * Have the HTML/XML TOC 'drill down' into the TOCs of the individual guides
  * `.epub` generation.
  