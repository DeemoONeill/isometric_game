package main

import "core:fmt"
import "core:log"
import "core:math"
import la "core:math/linalg"
import "core:mem"
import rl "vendor:raylib"

GRID_SIZE: [2]f32 : {100, 100}

SQUARE_SIZE: [2]f32 : {391, 450}

MOVE_MATRIX: matrix[2, 2]f32 : {0.5, 0.25, -0.5, 0.25}

INVERSE_MOVE: matrix[2, 2]f32 : {1, -1, 2, 2}
MOVEMENT_SPEED :: 500


KEY_PAN_SPEED :: 1000
MIN_ZOOM :: 0.05
MAX_ZOOM :: 0.7

character :: struct {
	path:                   ^[dynamic]rl.Vector2,
	sprite:                 rl.Texture2D,
	current_grid_position:  rl.Vector2,
	current_world_position: rl.Vector2,
	target_grid_position:   rl.Vector2,
	moving:                 bool,
}


main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}
	context.logger = log.create_console_logger(lowest = .Debug)
	defer log.destroy_console_logger(context.logger)


	rl.SetConfigFlags({.WINDOW_RESIZABLE, .WINDOW_ALWAYS_RUN})
	rl.InitWindow(1920, 1080, "isometric")
	rl.SetTargetFPS(60)

	cube_texture := rl.LoadTexture("assets/cube.png")
	sprite := rl.LoadTexture("assets/isometric_sprites.PNG")

	char: character = {
		current_grid_position = {0, 0},
		sprite                = sprite,
	}
	defer {if char.path != nil {delete_dynamic_array(char.path^)}}
	char.current_world_position = grid_to_world(char.current_grid_position)

	grid: [i32(GRID_SIZE.x)][i32(GRID_SIZE.y)]rl.Color
	for y in 0 ..< GRID_SIZE.y {
		for x in 0 ..< GRID_SIZE.x {
			grid[i32(x)][i32(y)] = {255, 255, 255, 150}
		}}

	animation_progress: f32
	camera := rl.Camera2D {
		offset = {800, 600},
		target = {30, 30},
		zoom   = 0.5,
	}

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()
		animation_progress += dt / 2
		mouse_wheel := rl.GetMouseWheelMove()

		camera.zoom = clamp(camera.zoom + (0.1 * mouse_wheel), MIN_ZOOM, MAX_ZOOM)

		if rl.IsMouseButtonDown(.LEFT) {
			camera.target -= rl.GetMouseDelta() * 2
		}

		if rl.IsKeyDown(.W) || rl.IsKeyDown(.UP) {
			camera.target.y -= KEY_PAN_SPEED * dt
		}
		if rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT) {
			camera.target.x -= KEY_PAN_SPEED * dt
		}
		if rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN) {
			camera.target.y += KEY_PAN_SPEED * dt
		}
		if rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT) {
			camera.target.x += KEY_PAN_SPEED * dt
		}

		rl.BeginDrawing()
		defer rl.EndDrawing()
		defer draw_ui()
		rl.BeginMode2D(camera)
		defer rl.EndMode2D()
		rl.ClearBackground(rl.BLACK)


		mouse := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)

		grid_pos := world_to_grid(mouse)
		grid_pos.x -= 1


		if in_grid(grid_pos) {
			grid[i32(grid_pos.x)][i32(grid_pos.y)] = rl.RED
		}

		if rl.IsMouseButtonPressed(.RIGHT) {
			if in_grid(grid_pos) {
				path, ok := a_star(char.current_grid_position, grid_pos)
				if !ok {
				} else {
					char.path = &path
					char.target_grid_position = pop(&path)
					char.moving = true
				}

			}
		}
		if char.moving {
			advance_character(&char, dt)
		}

		culling := calculate_culling(camera)


		for y in 0 ..< GRID_SIZE.y {
			for x in 0 ..< GRID_SIZE.x {
				res: [2]f32 = {x, y}
				offset: i32

				outcome := grid_to_world(res)
				if !rl.CheckCollisionRecs(
					culling,
					{outcome.x, outcome.y, SQUARE_SIZE.x, SQUARE_SIZE.y},
				) {
					continue
				}
				rl.DrawTextureV(
					cube_texture,
					outcome - {0, calc_offset(res, animation_progress)},
					grid[i32(x)][i32(y)],
				)


			}
		}

		if in_grid(grid_pos) {
			grid[i32(grid_pos.x)][i32(grid_pos.y)] = rl.WHITE
		}

		rl.DrawTextureEx(
			char.sprite,
			char.current_world_position +
			{30, -100} -
			{0, calc_offset(char.current_grid_position, animation_progress)},
			rotation = 0,
			scale = 5,
			tint = rl.WHITE,
		)

		rl.DrawText(fmt.ctprintf("%v, %v", char), 30, 30, 40, rl.GRAY)
	}


}

draw_ui :: proc() {

	rl.DrawFPS(10, 10)
	height := rl.GetScreenHeight()
	width := rl.GetScreenWidth()
	padding: i32 = width / 90
	v_pos := height - 120
	v_padding: i32 = height - v_pos - 10

	rl.DrawRectangle(padding, v_pos, width - (2 * padding), v_padding, rl.RED)
}

calc_offset :: proc(position: [2]f32, animation_progress: f32) -> f32 {
	x, y := position.x, position.y
	return(
		math.sin(animation_progress + 50 + ((x + x + y) / 3)) * 70 +
		math.cos(animation_progress + 50 + (y + y + x) / 3) * 70 \
	)

}

half_tile := SQUARE_SIZE / 2

world_to_grid :: proc(world_position: [2]f32) -> [2]f32 {
	local_pos := world_position + {half_tile.x, 0}
	grid_pos := local_pos / SQUARE_SIZE * INVERSE_MOVE

	return {math.round(grid_pos.x), math.round(grid_pos.y)}
}

grid_to_world :: proc(grid_pos: [2]f32) -> [2]f32 {
	world_pos := grid_pos * MOVE_MATRIX * SQUARE_SIZE
	world_pos -= {half_tile.x, 0}

	return world_pos

}

calculate_culling :: proc(camera: rl.Camera2D) -> rl.Rectangle {
	w, h := rl.GetScreenWidth(), rl.GetScreenHeight()
	origin := rl.GetScreenToWorld2D({0, 0}, camera)

	max := rl.GetScreenToWorld2D({f32(w), f32(h)}, camera)

	return rl.Rectangle {
		x = origin.x,
		y = origin.y,
		width = max.x - origin.x,
		height = max.y - origin.y,
	}
}

in_grid :: proc(position: rl.Vector2) -> bool {
	return(
		position.x >= 0 &&
		position.x < GRID_SIZE.x &&
		position.y >= 0 &&
		position.y < GRID_SIZE.y \
	)
}

advance_character :: proc(char: ^character, dt: f32) {
	epsilon: f32 = 10.0 // how close is "good enough" to the center (in pixels)

	char.current_grid_position = world_to_grid(char.current_world_position)

	target_world_pos := grid_to_world(char.target_grid_position)

	if len(char.path) > 0 && char.current_grid_position == char.target_grid_position {
		char.target_grid_position = pop(char.path)
	} else if rl.Vector2Distance(char.current_world_position, target_world_pos) < epsilon {
		// check if we're close enough to the *center* of the target
		char.moving = false
		return
	}

	// move towards the current target
	direction := rl.Vector2Normalize(target_world_pos - char.current_world_position)
	char.current_world_position += direction * dt * MOVEMENT_SPEED
}
