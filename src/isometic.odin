package main

import "core:fmt"
import "core:log"
import "core:math"
import la "core:math/linalg"
import rl "vendor:raylib"

GRID_SIZE: [2]f32 : {100, 100}

SQUARE_SIZE: [2]f32 : {391, 450}

mov: matrix[2, 2]f32 : {0.5, 0.25, -0.5, 0.25}

KEY_PAN_SPEED :: 30
MIN_ZOOM :: 0.05
MAX_ZOOM :: 0.7


main :: proc() {
	context.logger = log.create_console_logger(lowest = .Info)


	inverse := la.inverse(mov)
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .WINDOW_ALWAYS_RUN})
	rl.InitWindow(1920, 1080, "isometric")
	rl.SetTargetFPS(60)

	cube_texture := rl.LoadTexture("assets/cube.png")
	sprite := rl.LoadTexture("assets/isometric_sprites.PNG")


	grid: [i32(GRID_SIZE.x)][i32(GRID_SIZE.y)]rl.Color
	for y in 0 ..< GRID_SIZE.y {
		for x in 0 ..< GRID_SIZE.x {
			grid[i32(x)][i32(y)] = rl.WHITE
		}}

	animation_progress: f32
	camera := rl.Camera2D {
		offset = {800, 600},
		target = {30, 30},
		zoom   = 0.5,
	}

	for !rl.WindowShouldClose() {
		animation_progress += rl.GetFrameTime() / 2
		mouse_wheel := rl.GetMouseWheelMove()

		camera.zoom = clamp(camera.zoom + (0.1 * mouse_wheel), MIN_ZOOM, MAX_ZOOM)

		if rl.IsMouseButtonDown(.LEFT) {
			camera.target -= rl.GetMouseDelta() * 2
		}

		if rl.IsKeyDown(.W) || rl.IsKeyDown(.UP) {
			camera.target.y -= KEY_PAN_SPEED
		}
		if rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT) {
			camera.target.x -= KEY_PAN_SPEED
		}
		if rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN) {
			camera.target.y += KEY_PAN_SPEED
		}
		if rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT) {
			camera.target.x += KEY_PAN_SPEED
		}

		rl.BeginDrawing()
		defer rl.EndDrawing()
		// defer draw_ui()
		rl.BeginMode2D(camera)
		defer rl.EndMode2D()
		// screen := rl.GetScreenToWorld2D({10, 10}, camera)
		rl.ClearBackground(rl.BLACK)


		mouse := rl.GetMousePosition()

		grid_pos := (mouse * inverse)

		grid_pos.x -= SQUARE_SIZE.x / 2


		grid_pos /= SQUARE_SIZE
		grid_pos.y += 2

		grid_pos.x = math.floor(grid_pos.x)
		grid_pos.y = math.floor(grid_pos.y)


		for y in 0 ..< GRID_SIZE.y {
			for x in 0 ..< GRID_SIZE.x {
				res: [2]f32 = {x, y}
				outcome := res * mov * SQUARE_SIZE
				offset := i32(calc_offset(x, y, animation_progress))

				x_pos := i32(outcome.x) - i32(SQUARE_SIZE.x) / 2

				y_pos := i32(outcome.y) + (offset)
				if y == 0 && x == 0 {
					// fmt.printfln("grid_pos %d", y_pos)
					log.debugf("grid_pos: %d", y_pos)
				}
				rl.DrawTexture(cube_texture, x_pos, y_pos, grid[i32(x)][i32(y)])

			}
		}

		cell: [2]f32 = {0, 0}
		screen_pos := cell * mov
		x, y := cell.x, cell.y
		offset := calc_offset(x, y, animation_progress)

		x_pos := screen_pos.x - (SQUARE_SIZE.x / 2) + 50
		y_pos := screen_pos.y - offset - (SQUARE_SIZE.y / 4)
		log.debug(y_pos)

		rl.DrawTextureEx(
			sprite,
			{x_pos, y_pos},
			rotation = 0,
			scale = 5,
			tint = grid[i32(x)][i32(y)],
		)


		// rl.DrawText(fmt.ctprint(rl.GetFPS()), i32(10), i32(10), 30, rl.GREEN)

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

calc_offset :: proc(x, y, animation_progress: f32) -> f32 {
	return(
		math.sin(animation_progress + 50 + ((x + x + y) / 3)) * 70 +
		math.cos(animation_progress + 50 + (y + y + x) / 3) * 70 \
	)

}
