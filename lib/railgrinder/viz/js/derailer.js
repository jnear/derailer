Array.prototype.getUnique = function(){
   var u = {}, a = [];
   for(var i = 0, l = this.length; i < l; ++i){
      if(u.hasOwnProperty(this[i])) {
         continue;
      }
      a.push(this[i]);
      u[this[i]] = 1;
   }
   return a;
}

var selected = null;
var current_constraints = [];

var w = 700,
    h = 2000,
    i = 0,
    barHeight = 25,
    barWidth = w * .8,
    duration = 400,
    root;

var tree, diagonal, vis;

function init() {
    d3.json("../constraint_graph.json", function(json) {
	    h = tree.nodes(json).length*barHeight;
	    d3.select("#chart1").style("height", 100);
	});

    tree = d3.layout.tree()
	.size([h, 100]);

    diagonal = d3.svg.diagonal()
	.projection(function(d) { return [d.y, d.x]; });

    vis = d3.select("#chart1").append("svg:svg")
	.attr("width", w)
	.attr("height", h)
	.append("svg:g")
	.attr("transform", "translate(20,30)");

    d3.json("../constraint_graph.json", function(json) {
	    json.x0 = 0;
	    json.y0 = 0;
	    update(root = json);
	});
}

function allowDrop(ev) {
  ev.preventDefault();
}

function drag(ev) {
  ev.dataTransfer.setData("Text",ev.target.id);
}

function drop(ev) {
  ev.preventDefault();
  var data=ev.dataTransfer.getData("Text");
  ev.target.appendChild(document.getElementById(data));



  current_constraints.push(data);

  tree.nodes(root).forEach(function(d,i){
    if (d.children == null && d._children != null) {
      d.was_open = 1;
      d.children = d._children;
    }});

  update(root);

  // wrong but no time to fix it now
  vis.selectAll("g.node").filter(function(d,i) {
    var to_remove = false;
    if (typeof d.constraints != 'undefined') {
      d.constraints.forEach(function(n, i) {
        if (current_constraints.indexOf(n) > -1) {
	    // this ting is supposed to remove parents that have no remaining children
	    // but it's wrong
	    //d.parent.parent.children.splice(d.parent.parent.children.indexOf(d.parent),1);
	    // this should remove just me?
	    d.parent.children.splice(d,1);
          // d.remove();
          to_remove = true;
          return;
        }});
      }
    if (to_remove) { return true; } else { return false; }
    }).remove();

  update(root);

  tree.nodes(root).forEach(function(d,i){
    if (d.was_open == 1) {
      d.was_open = 0;
      d._children = d.children;
      d.children = null;
    }});


  update(root);

}





function update(source) {
  // Compute the flattened node list. TODO use d3.layout.hierarchy.
  var nodes = tree.nodes(root);
   
  // Compute the "layout".
  nodes.forEach(function(n, i) {
    n.x = i * barHeight *1.2;
  });


  
  // Update the nodes…
  var node = vis.selectAll("g.node")
      .data(nodes, function(d) { return d.id || (d.id = ++i); });
  
  var nodeEnter = node.enter().append("svg:g")
      .attr("class", "node")
      .attr("transform", function(d) { return "translate(" + source.y0 + "," + source.x0 + ")"; })
      .style("opacity", 1e-6);

  // Enter any new nodes at the parent's previous position.
  nodeEnter.append("svg:rect")
      .attr("y", -barHeight / 2)
      .attr("height", barHeight)
      .attr("width", barWidth)
      .attr("rx", 3)
      .attr("ry", 3)
      .style("fill", color)
      .on("click", click);
  
  nodeEnter.append("svg:text")
      .attr("dy", 4.0)
      .attr("dx", 7.5)
      .text(function(d) { return d.name; });
  
  // Transition nodes to their new position.
  nodeEnter.transition()
      .duration(duration)
      .attr("transform", function(d) { return "translate(" + d.y + "," + d.x + ")"; })
      .style("opacity", 1);
  
  node.transition()
      .duration(duration)
      .attr("transform", function(d) { return "translate(" + d.y + "," + d.x + ")"; })
      .style("opacity", 1)
    .select("rect")
      .style("fill", color);
  
  // Transition exiting nodes to the parent's new position.
  node.exit().transition()
      .duration(duration)
      .attr("transform", function(d) { return "translate(" + source.y + "," + source.x + ")"; })
      .style("opacity", 1e-6)
      .remove();
  
  // Update the links…
  var link = vis.selectAll("path.link")
      .data(tree.links(nodes), function(d) { return d.target.id; });
  
  // Enter any new links at the parent's previous position.
  link.enter().insert("svg:path", "g")
      .attr("class", "link")
      .attr("d", function(d) {
        var o = {x: source.x0, y: source.y0};
        return diagonal({source: o, target: o});
      })
    .transition()
      .duration(duration)
      .attr("d", diagonal);
  
  // Transition links to their new position.
  link.transition()
      .duration(duration)
      .attr("d", diagonal);
  
  // Transition exiting nodes to the parent's new position.
  link.exit().transition()
      .duration(duration)
      .attr("d", function(d) {
        var o = {x: source.x, y: source.y};
        return diagonal({source: o, target: o});
      })
      .remove();
  
  // Stash the old positions for transition.
  nodes.forEach(function(d) {
    d.x0 = d.x;
    d.y0 = d.y;
  });
}

// Toggle children on click.
function click(d) {
  if (d.children) {
    d._children = d.children;
    d.children = null;
  } else {
    d.children = d._children;
    d._children = null;
  }
  selected = d;
  update(d);

  if (!(d.children || d._children)) {
    d3.select("#popup_box_data").html("");
    d3.select("#popup_box_header").html("Constraints: 0");
  }


  if (typeof d.constraints != 'undefined' && d.constraints.length > 0) {
    d3.select("#popup_box_data").html("");
    /* get_constraints(d) */

    var constraints = d.constraints.getUnique();
    var constraints_div = d3.select("#popup_box_data");
    d3.select("#popup_box_header").html("Constraints: " + constraints.length);

    constraints.forEach(function(c) {
	    constraints_div.append("div")
		.attr("class", "panel panel-default")
		.attr("id", c).attr("draggable", "true")
		.attr("ondragstart", "drag(event)")
		.on("click", function() {
			console.log(c);
			d3.select(this).remove();
			d3.event.stopPropagation(); 
		    })
		.append("div").attr("class", "panel-body constraint").html(c);
	});
  }

}

function color(d) {
    return d._children ? "#3182bd" : d.children ? "#c6dbef" : d == selected ? "#fd8d3c": "#ffea8f";
}

$(window).bind("load", function() {
	init();
});