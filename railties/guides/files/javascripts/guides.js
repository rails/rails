function guideMenu(){
  if (document.getElementById('guides').style.display == "none") {
    document.getElementById('guides').style.display = "block";
  } else {
    document.getElementById('guides').style.display = "none";
  }
}

// Fix Copy+Paste of Code blocks in Firefox 3
if ( window.addEventListener && document.getElementsByClassName ) {
  window.addEventListener('load', function() {
    var list = document.getElementsByClassName('code_container');
    for (var i=0, len=list.length; i<len; i++) {
      list[i].innerHTML = list[i].innerHTML.replace(/\n/g, '<br />');
    }
  }, false);
}
