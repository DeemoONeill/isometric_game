#+feature dynamic-literals
package main

import queue "core:container/priority_queue"
import "core:fmt"
import "core:math"
import rl "vendor:raylib"

node :: struct {
	position: rl.Vector2,
	distance: f32,
}

DIRECTIONS: [4]rl.Vector2 : {{-1, 0}, {1, 0}, {0, -1}, {0, 1}}

reconstruct_path :: proc(
	cameFrom: map[rl.Vector2]rl.Vector2,
	current: rl.Vector2,
) -> [dynamic]rl.Vector2 {
	current := current
	total_path: [dynamic]rl.Vector2 = {current}
	for (current in cameFrom) {
		current = cameFrom[current]
		append(&total_path, current)
	}

	return total_path

}

Callback :: proc(node, goal: rl.Vector2) -> f32

manhattan_distance :: proc(node, goal: rl.Vector2) -> f32 {
	return math.abs(node.x - goal.x) + math.abs(node.y - goal.y)
}
euclid_distance :: proc(node, goal: rl.Vector2) -> f32 {
	return math.sqrt(math.pow((node.x - goal.x), 2) + math.pow((node.y - goal.y), 2))
}
less :: proc(a, b: node) -> bool {
	return a.distance <= b.distance
}


a_star :: proc(
	start, goal: rl.Vector2,
	h: Callback = euclid_distance,
) -> (
	[dynamic]rl.Vector2,
	bool,
) {

	openSet: queue.Priority_Queue(node) = {}
	backing_array: [dynamic]node = {}
	defer queue.destroy(&openSet)


	queue.init_from_dynamic_array(
		&openSet,
		backing_array,
		less = less,
		swap = queue.default_swap_proc(node),
	)

	queue.push(&openSet, node{start, h(start, goal)})

	came_from: map[rl.Vector2]rl.Vector2
	defer delete(came_from)

	gscore: map[rl.Vector2]f32
	defer delete(gscore)
	gscore[start] = 0

	for queue.len(openSet) > 0 {
		current := queue.pop(&openSet)
		if current.position == goal {
			return reconstruct_path(came_from, current.position), true
		}
		for direction in DIRECTIONS {
			neighbor := current.position + direction
			if !in_grid(neighbor) {
				continue
			}
			tentative_gscore := gscore[current.position] + 1
			if !(neighbor in gscore) {
				gscore[neighbor] = math.INF_F32
			}
			if tentative_gscore < gscore[neighbor] {
				came_from[neighbor] = current.position
				gscore[neighbor] = tentative_gscore
				queue.push(&openSet, node{neighbor, tentative_gscore + h(neighbor, goal)})
			}
		}
	}


	return {}, false


}
/*
function reconstruct_path(cameFrom, current)
    total_path := {current}
    while current in cameFrom.Keys:
        current := cameFrom[current]
        total_path.prepend(current)
    return total_path

// A* finds a path from start to goal.
// h is the heuristic function. h(n) estimates the cost to reach goal from node n.
function A_Star(start, goal, h)
    // The set of discovered nodes that may need to be (re-)expanded.
    // Initially, only the start node is known.
    // This is usually implemented as a min-heap or priority queue rather than a hash-set.
    openSet := {start}

    // For node n, cameFrom[n] is the node immediately preceding it on the cheapest path from the start
    // to n currently known.
    cameFrom := an empty map

    // For node n, gScore[n] is the currently known cost of the cheapest path from start to n.
    gScore := map with default value of Infinity
    gScore[start] := 0

    // For node n, fScore[n] := gScore[n] + h(n). fScore[n] represents our current best guess as to
    // how cheap a path could be from start to finish if it goes through n.
    fScore := map with default value of Infinity
    fScore[start] := h(start)

    while openSet is not empty
        // This operation can occur in O(Log(N)) time if openSet is a min-heap or a priority queue
        current := the node in openSet having the lowest fScore[] value
        if current = goal
            return reconstruct_path(cameFrom, current)

        openSet.Remove(current)


    // Open set is empty but goal was never reached
    return failure
*/
