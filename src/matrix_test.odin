package main
import "core:testing"

@(test)
test_matrix_functions :: proc(t: ^testing.T) {
	for x in 0 ..< 100 {
		for y in 0 ..< 100 {
			grid: [2]f32 = {f32(x), f32(y)}
			result := grid_to_world(grid)
			result += SQUARE_SIZE / 5
			testing.expect_value(t, world_to_grid(result), grid)
		}
	}
}
