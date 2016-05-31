#!/usr/bin ruby

# This scripts is a wrapper for locally logging SSH sesions
# Copyright (C) 2016  Juan Antonio Aldea-Armenteros
#
#
# Foobar is free software: you can redistribute it and/or modify
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
# along with Foobar.  If not, see <http://www.gnu.org/licenses/>.

require 'pp'
require 'set'

graph  = {
    'A' => {:depends_on => ['B', 'C'], :required_by => []},
    'B' => {:depends_on => ['D'], :required_by => ['A']},
    'C' => {:depends_on => [], :required_by => ['A']},
    'D' => {:depends_on => [], :required_by => ['B']},
    #'E' => {:depends_on => [], :required_by => ['B', 'C', 'D']},
}

def to_dot_language (graph)
    edges = ""
    configuration = ""
    graph.each do | source_node, value |
        value[:depends_on].each do | destination_node |
            edges += "\t#{source_node} -> #{destination_node};\n"
        end
    end
    graph_str = "digraph {\n#{configuration}\n #{edges}}";
    return graph_str
end

def get_partial_graph(graph, target_node)
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

    #list involved nodes
    involved_nodes = []
    partial_graph.each do | node, _ |
        if !involved_nodes.include?(node)
            involved_nodes.push(node)
        end
    end

    #remove uninvolved nodes from the graph
    partial_graph.each do | node, neighbour_nodes |
        neighbour_nodes[:depends_on] = neighbour_nodes[:depends_on] & involved_nodes
        neighbour_nodes[:required_by] = neighbour_nodes[:required_by] & involved_nodes
    end

    return partial_graph
end

def topological_partial_sorting(graph, target_node)
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

    partial_graph = get_partial_graph(graph, target_node)
    puts "partial graph "
    pp partial_graph


    #get involved nodes and their indegree
    node_indegree = {}
    partial_graph.each do | node, neighbour_nodes |
        node_indegree[node] = neighbour_nodes[:required_by].length
    end
    print "node indegree "
    pp node_indegree

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
            partial_graph[node][:depends_on].each { | dependency | node_indegree[dependency] -= 1 }
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

def deph_graph_for_action(graph, component, action)
    action_list = topological_partial_sorting(graph)
    print "action_list "
    pp action_list
    action_sub_list = []

    action_list.each do | components |
        if components.include?(component)
            action_sub_list.push([component])
            break
        else
            action_sub_list.push(components)
        end
    end

    if action == 'start'
        return action_sub_list.reverse
    elsif action == 'stop'
        return action_sub_list
    end

    return []
end

pp graph


dot_graph = to_dot_language(graph)
#puts dot_graph
%x[echo "#{dot_graph}" | dot -Tpng -o graph.png]

action_list = topological_partial_sorting(graph, 'D')
pp action_list
dot_action_graph = action_graph_to_dot_language(action_list)
#puts dot_action_graph
%x[echo "#{dot_action_graph}" | dot -Tpng -o graph_action.png]

#stop_graph = deph_graph_for_action(graph, 'D', "stop")
#pp stop_graph
#dot_action_graph = action_graph_to_dot_language(stop_graph)
#%x[echo "#{dot_action_graph}" | dot -Tpng -o stop_graph_action.png]


#pp graph
