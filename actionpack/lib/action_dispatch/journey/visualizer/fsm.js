function tokenize(input, callback) {
  while(input.length > 0) {
    callback(input.match(/^[\/\.\?]|[^\/\.\?]+/)[0]);
    input = input.replace(/^[\/\.\?]|[^\/\.\?]+/, '');
  }
}

var graph = d3.select("#chart-2 svg");
var svg_edges = {};
var svg_nodes = {};

graph.selectAll("g.edge").each(function() {
  var node  = d3.select(this);
  var index = node.select("title").text().split("->");
  var left  = parseInt(index[0]);
  var right = parseInt(index[1]);

  if(!svg_edges[left]) { svg_edges[left] = {} }
  svg_edges[left][right] = node;
});

graph.selectAll("g.node").each(function() {
  var node  = d3.select(this);
  var index = parseInt(node.select("title").text());
  svg_nodes[index] = node;
});

function reset_graph() {
  for(var key in svg_edges) {
    for(var mkey in svg_edges[key]) {
      var node = svg_edges[key][mkey];
      var path = node.select("path");
      var arrow = node.select("polygon");
      path.style("stroke", "black");
      arrow.style("stroke", "black").style("fill", "black");
    }
  }

  for(var key in svg_nodes) {
    var node = svg_nodes[key];
    node.select('ellipse').style("fill", "white");
    node.select('polygon').style("fill", "white");
  }
  return false;
}

function highlight_edge(from, to) {
  var node = svg_edges[from][to];
  var path = node.select("path");
  var arrow = node.select("polygon");

  path
    .transition().duration(500)
    .style("stroke", "green");

  arrow
    .transition().duration(500)
    .style("stroke", "green").style("fill", "green");
}

function highlight_state(index, color) {
  if(!color) { color = "green"; }

  svg_nodes[index].select('ellipse')
    .style("fill", "white")
    .transition().duration(500)
    .style("fill", color);
}

function highlight_finish(index) {
  svg_nodes[index].select('ellipse')
    .style("fill", "while")
    .transition().duration(500)
    .style("fill", "blue");
}

function match(input) {
  reset_graph();
  var table           = tt();
  var states          = [[0, null]];
  var regexp_states   = table['regexp_states'];
  var string_states   = table['string_states'];
  var stdparam_states = table['stdparam_states'];
  var accepting       = table['accepting'];
  var default_re      = new RegExp("^[^.\/?]+$");
  var start_index     = 0;

  highlight_state(0);

  tokenize(input, function(token) {
    var end_index = start_index + token.length;

    var new_states = [];
    for(var key in states) {
      var state_parts = states[key];
      var state = state_parts[0];
      var previous_start = state_parts[1];

      if(previous_start == null) {
        if(string_states[state] && string_states[state][token]) {
          var new_state = string_states[state][token];
          highlight_edge(state, new_state);
          highlight_state(new_state);
          new_states.push([new_state, null]);
        }

        if(stdparam_states[state] && default_re.test(token)) {
          for(var key in stdparam_states[state]) {
            var new_state = stdparam_states[state][key];
            highlight_edge(state, new_state);
            highlight_state(new_state);
            new_states.push([new_state, null]);
          }
        }
      }

      if(regexp_states[state]) {
        var slice_start = previous_start != null ? previous_start : start_index;
        
        for(var key in regexp_states[state]) {
          var re = new RegExp("^" + key + "$");

          var accumulation = input.slice(slice_start, end_index);

          if(re.test(accumulation)) {
            var new_state = regexp_states[state][key];
            highlight_edge(state, new_state);
            highlight_state(new_state);
            new_states.push([new_state, null]);
          }

          // retry the same regexp with the accumulated data either way
          new_states.push([state, slice_start]);
        }
      }
    }

    states = new_states;
    start_index = end_index;
  });

  for(var key in states) {
    var state_parts = states[key];
    var state = state_parts[0];
    var slice_start = state_parts[1];
    
    // we must ignore ones that are still accepting more data
    if (slice_start != null) continue;

    if(accepting[state]) {
      // for(var mkey in svg_edges[state]) {
      //   if(!regexp_states[mkey] && !string_states[mkey]) {
      //     highlight_edge(state, mkey);
      //     highlight_finish(mkey);
      //   }
      // }
      highlight_finish(state);
    } else {
      highlight_state(state, "red");
    }
  }

  return false;
}

