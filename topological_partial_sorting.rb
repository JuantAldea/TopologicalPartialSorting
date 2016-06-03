#!/usr/bin ruby

# This scripts is a wrapper for locally logging SSH sesions
# Copyright (C) 2016  Juan Antonio Aldea-Armenteros
#
#
# This code is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this code. If not, see <http://www.gnu.org/licenses/>.

require 'pp'
require 'set'

graph  = {
    'A' => {:depends_on => ['B', 'C', 'D'], :required_by => []},
    'B' => {:depends_on => ['D'], :required_by => ['A']},
    'C' => {:depends_on => [], :required_by => ['A']},
    'D' => {:depends_on => [], :required_by => ['B', 'A']},
    'E' => {:depends_on => [], :required_by => ['F']},
    'F' => {:depends_on => ['E'], :required_by => []},
    #'E' => {:depends_on => [], :required_by => ['B', 'C', 'D']},
}

def get_partial_graph (graph, target_nodes, action)
    partial_graph = {}
    target_nodes = [target_nodes].flatten
    
    target_nodes.each do | node |
        partial_graph[node] = graph[node].clone
    end

    dependency_directions = (action == 'stop') ? [:required_by, :depends_on] : [:depends_on, :required_by]

    s = Set.new()
    target_nodes.each do | node |
        s += Set.new(graph[node][dependency_directions[0]])
    end

    visited = Set.new()
    while !s.empty?
        node = s.take(1)
        s.subtract(node)
        node = node[0]
        visited += [node]
        partial_graph[node] = graph[node]
        s += Set.new(graph[node][dependency_directions[0]].select {|node| !visited.include? node})
        #pp s
        pp partial_graph
    end

    #list involved nodes
    involved_nodes = []
    partial_graph.each do | node, _ |
        if !involved_nodes.include?(node)
            involved_nodes.push(node)
        end
    end

    #remove uninvolved nodes from the graph
    partial_graph.each do | node, neighbour_nodes |
        neighbour_nodes[dependency_directions[1]] = neighbour_nodes[dependency_directions[1]] & involved_nodes
        neighbour_nodes[dependency_directions[0]] = neighbour_nodes[dependency_directions[0]] & involved_nodes
    end

    return partial_graph
end

def topological_partial_sorting (graph, target_node, action)
=begin
    partial_graph = {}
    partial_graph[target_node] = graph[target_node]

    s = Set.new(graph[target_node][:required_by])
    while !s.empty?
        node = s.take(1)
        s.subtract(node)
        node = node[0]
        partial_graph[node] = graph[node]
        s += Set.new(graph[node][:required_by])
    end
    #puts "partial_graph"
    #pp partial_graph
=end
=begin

    partial_graph = get_partial_graph(graph, target_node)
    puts "partial graph "
    pp partial_graph
=end

    #get involved nodes and their indegree
    dependency_directions = (action == 'stop') ? [:required_by, :depends_on] : [:depends_on, :required_by]
    #dependency_directions = [:required_by, :depends_on]
    node_indegree = {}
    graph.each do | node, neighbour_nodes |
        node_indegree[node] = neighbour_nodes[dependency_directions[0]].length
    end
    
=begin
    #remove uninvolved nodes

    partial_graph.each do | node, neighbour_nodes |
        neighbour_nodes[:depends_on] = neighbour_nodes[:depends_on] & node_indegree.keys
        neighbour_nodes[:required_by] = neighbour_nodes[:required_by] & node_indegree.keys
    end

    pp partial_graph
    puts "============"
=end

    unordered_node_clusters = []
    nodes_without_deps = Set.new(node_indegree.keys.select { |node| node_indegree[node] == 0 })
    while !nodes_without_deps.empty?
        unordered_nodes = []
        while !nodes_without_deps.empty?
            node = nodes_without_deps.take(1)
            nodes_without_deps.subtract(node)
            node = node[0]
            unordered_nodes.push(node)
            graph[node][dependency_directions[1]].each { | dependency | pp dependency; node_indegree[dependency] -= 1 }
            node_indegree[node] = -1
        end
        unordered_node_clusters.push(unordered_nodes)
        nodes_without_deps = Set.new(node_indegree.keys.select { |node| node_indegree[node] == 0 })
    end

    if !node_indegree.values.all? { |value| value == -1}
        puts "CYCLE DETECTED"
        return []
    end

    return unordered_node_clusters
end

def deph_graph_for_action (action_list, component, action)
    #action_list = topological_partial_sorting(graph)
    #print "action_list "
    #pp action_list
    
    if action == 'start'
        action_list = action_list.reverse
    end

    action_sub_list = []
    action_list.each do | components |
        if components.include?(component)
            action_sub_list.push([component])
            break
        else
            action_sub_list.push(components)
        end
    end


    return action_sub_list
end

def action_graph_to_dot_language (list)
    configuration = "layout=fdp; compound=true; nodesep=1.0;\n"

    subgraphs = ""
    list.each do | cluster |
        cluster_nodes = '';
        cluster.each do | node |
            cluster_nodes += "#{node}; "
        end
        subgraphs += "\tsubgraph cluster_#{cluster.join} { #{cluster_nodes}}\n"
    end

    cluster_edges = ''
    for i in 0...list.length - 1
        origin = "cluster_#{list[i].join}"
        destination = "cluster_#{list[i + 1].join}"
        cluster_edges += "\t#{origin} -> #{destination} [ltail=#{origin}, lhead=#{destination}];\n"
    end

    return "digraph G {\n\t#{configuration}\n#{subgraphs}\n#{cluster_edges}}";
end

def to_dot_language (graph)
    edges = ""
    configuration = ""
    pp "BROZA"
    pp graph
    graph.each do | source_node, value |
        value[:depends_on].each do | destination_node |
            edges += "\t#{source_node} -> #{destination_node};\n"
        end
    end
    graph_str = "digraph {\n#{configuration}\n #{edges}}";
    pp graph_str
    return graph_str
end

pp graph

COMP = ARGV[1...ARGV.length]

pp COMP

ACTION = ARGV[0]

dot_graph = to_dot_language(graph)
#puts dot_graph
%x[echo "#{dot_graph}" | dot -Tpng -o graph.png]

partial_graph = get_partial_graph(graph, COMP, ACTION)
puts "patial graph "
pp partial_graph

action_list = topological_partial_sorting(partial_graph, COMP, ACTION)
print "action list "
pp action_list

dot_action_graph = action_graph_to_dot_language(action_list)
#puts dot_action_graph
%x[echo "#{dot_action_graph}" | dot -Tpng -o graph_action.png]

action_graph = deph_graph_for_action(action_list, COMP, "pollica")
print "action_graph "
pp action_graph
#dot_action_graph = action_graph_to_dot_language(stop_graph)
#%x[echo "#{dot_action_graph}" | dot -Tpng -o stop_graph_action.png]


#pp graph
