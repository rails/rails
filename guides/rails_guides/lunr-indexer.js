var idx = lunr(function () {
  this.ref('id')
  this.field('title')
  this.field('heading')
  this.field('subheading')
  this.field('content')
  this.metadataWhitelist = ['position']
  lunrDocuments.forEach(function (doc) {
    this.add(doc)
  }, this)
})
return JSON.stringify(idx);
