# node.jl
import Base: isequal, ==, isless, Dict

struct NodeEdge
    edge₁::UInt8
    edge₂::UInt8
end

function convert_lightgraphs_edges_to_node_edges(g_edges::Array{LightGraphs.SimpleGraphs.SimpleEdge{Int64},1})::Array{NodeEdge, 1}
    node_edges = Array{NodeEdge, 1}([])
    for edge in g_edges
        push!(node_edges, NodeEdge(edge.src, edge.dst))
    end
    return node_edges
end

######################## ForbiddenPair #########################
# comp₁ < comp₂ by requirement
struct ForbiddenPair
    comp₁::UInt8
    comp₂::UInt8
end

==(p::ForbiddenPair, q::ForbiddenPair) = (p.comp₁==q.comp₁) & (p.comp₂==q.comp₂)

isequal(p::ForbiddenPair, q::ForbiddenPair) = isequal(p.comp₁,q.comp₁) & isequal(p.comp₂,q.comp₂)
isless(p::ForbiddenPair, q::ForbiddenPair) = ifelse(!isequal(p.comp₁,q.comp₁), isless(p.comp₁,q.comp₁), isless(p.comp₂,q.comp₂))

Base.hash(fp::ForbiddenPair, h::UInt) = hash(fp.comp₁, hash(fp.comp₂, h))

#######################   Node   ##################################

# The 1st node is always the 0-terminal, and the 2nd node is always the 1 terminal. Adding the first node to the ZDD
# means the ZDD will have 3 nodes, the node + the two terminal nodes
mutable struct Node
    label::NodeEdge
    cc::UInt8                   # can hold only 256 possible values
    fps::Vector{ForbiddenPair}
    comp_assign::Vector{UInt8}  # only 256 possible values
    deadend::Bool
    first_idx::UInt8
    hash::UInt64

    # allow for incomplete initialization
    function Node()::Node
        new()
    end

    function Node(i::Int)::Node # for Terminal Nodes
        node = new(NodeEdge(i, i), 0, Vector{ForbiddenPair}(), Vector{UInt8}([]), true, UInt8(1), 0)
        node.hash = hash(node)
        return node
    end

    function Node(root_edge::NodeEdge, base_graph::SimpleGraph)::Node
        comp_assign = Vector{UInt8}([i for i in 1:nv(base_graph)])
        node = new(root_edge, 0, Vector{ForbiddenPair}(), comp_assign, true, UInt8(1), 0)
        node.hash = hash(node)
        return node
    end

    function Node(label::NodeEdge,
                  cc::UInt8, fps::Vector{ForbiddenPair}, comp_assign::Vector{UInt8},
                  deadend::Bool, first_idx::UInt8)::Node
        return new(label, cc, fps, comp_assign, deadend, first_idx, 0)
    end
end

function copy_to_vec!(vec₁::Vector{T}, vec₂::Vector{T}) where T
    """ Copy items from vec₁ into vec₂.
        It is assumed that length(vec₂) >= length(vec₁)
    """
    for (i, item) in enumerate(vec₁)
        @inbounds vec₂[i] = item
    end
end

function copy_to_vec_from_idx!(vec₁::Vector{T}, vec₂::Vector{T}, idx::UInt8) where T
    """ Copy items from vec₁ into vec₂.
        It is assumed that length(vec₂) >= length(vec₁)
    """
    for i = idx:length(vec₁)
        @inbounds vec₂[i] = vec₁[i]
    end
end

function custom_deepcopy(n::Node, recycler::Stack{Node}, x::Int8)::Node
    if x == 1
        return n
    end
    if isempty(recycler)
        comp_assign = Vector{UInt8}(undef, length(n.comp_assign))
        fps = Vector{ForbiddenPair}(undef, length(n.fps))

        # copy_to_vec!(n.comp, comp)
        copy_to_vec_from_idx!(n.comp_assign, comp_assign, n.first_idx)
        copy_to_vec!(n.fps, fps)

        return Node(n.label, n.cc, fps, comp_assign, true, n.first_idx)
    else
        n′ = pop!(recycler)

        # empty the fields
        resize!(n′.fps, length(n.fps))

        # fill
        copy_to_vec!(n.fps, n′.fps)
        copy_to_vec_from_idx!(n.comp_assign, n′.comp_assign, n.first_idx)

        n′.cc = n.cc
        n′.first_idx = n.first_idx
        n′.deadend = n.deadend
        n′.label = n.label

        return n′
    end
end

function Base.isequal(node₁::Node, node₂::Node)
    node₁.hash == node₂.hash
end

function Base.hash(n::Node, h::UInt)
    comp_assign = @view n.comp_assign[n.first_idx:end]
    hash(n.label, hash(n.cc, hash(n.fps, hash(comp_assign, h))))
end

function Base.hashindex(node::Node, sz)::Int
    (((node.hash %Int) & (sz-1)) + 1)
end

Base.hash(n::Node, h::UInt) = hash(n.label, hash(n.cc, hash(n.fps, hash(n.comp_assign, hash(:Node, h)))))

function node_summary(node::Node)
    println("Label: ", readable(node.label))
    println("cc: ", readable(node.cc))
    println("comp: ", readable(node.comp))
    println("fps: ", readable(node.fps))
    println("comp_assign: ", readable(node.comp_assign))
    println()
end

function readable(edge::NodeEdge)::String
    "NodeEdge(" * string(Int64(edge.edge₁)) * " -> " * string(Int64(edge.edge₂)) * ")"
end

function readable(arr::Array{UInt8, 1})::Array{Int64, 1}
    Array{Int, 1}([Int64(x) for x in arr])
end

function readable(cc::UInt8)::Int64
    Int64(cc)
end

function readable(fp::ForbiddenPair)::String
    "ForbiddenPair(" * string(Int64(fp.comp₁)) * " -> " * string(Int64(fp.comp₂)) * ")"
end

function readable(fps::Vector{ForbiddenPair})::Vector{String}
    readable_vec = Vector{String}([])
    for fp in fps
        push!(readable_vec, readable(fp))
    end
    readable_vec
end
