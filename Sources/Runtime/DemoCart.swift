import Console

public enum DemoCart {
    public static let mainLua = """
        local floor, wall = 0, 1
        local floor_palette, wall_palette = 2, 4
        local player = 0
        local tile_size, map_cells = 8, 32
        local screen_width, screen_height = 192, 144
        local camera_max_x = map_cells * tile_size - screen_width
        local camera_max_y = map_cells * tile_size - screen_height

        function _init()
          for y = 0, map_cells - 1 do
            for x = 0, map_cells - 1 do
              local is_border = x == 0 or y == 0 or x == map_cells - 1 or y == map_cells - 1
              local is_pillar = x % 8 == 3 and y % 8 == 5
              if is_border or is_pillar then
                mset(x, y, wall, wall_palette)
              else
                mset(x, y, floor, floor_palette)
              end
            end
          end
          px, py = 88, 64
          palette = 7
          facing_left = false
        end

        local function is_wall_at(x, y)
          return mget(x // tile_size, y // tile_size) == wall
        end

        local function is_blocked(x, y)
          local right, bottom = x + tile_size - 1, y + tile_size - 1
          return is_wall_at(x, y) or is_wall_at(right, y) or is_wall_at(x, bottom) or is_wall_at(right, bottom)
        end

        function _update()
          local dx, dy = 0, 0
          if btn(0) then dx = dx - 1 end
          if btn(1) then dx = dx + 1 end
          if btn(2) then dy = dy - 1 end
          if btn(3) then dy = dy + 1 end
          if dx ~= 0 then facing_left = dx < 0 end
          if not is_blocked(px + dx, py) then px = px + dx end
          if not is_blocked(px, py + dy) then py = py + dy end
          if btnp(4) then palette = (palette + 1) % 8 end
        end

        local function clamp(value, low, high)
          return math.max(low, math.min(value, high))
        end

        function _draw()
          cls()
          local camera_x = px + tile_size // 2 - screen_width // 2
          local camera_y = py + tile_size // 2 - screen_height // 2
          camera(clamp(camera_x, 0, camera_max_x), clamp(camera_y, 0, camera_max_y))
          spr(player, px, py, palette, facing_left)
        end
        """

    public static func ppuWithTiles() -> PPU {
        var ppu = PPU()
        setTile(0, to: floorTile, in: &ppu.backgroundTiles)
        setTile(1, to: wallTile, in: &ppu.backgroundTiles)
        setTile(0, to: playerFacingRightTile, in: &ppu.spriteTiles)
        return ppu
    }

    private static let floorTile = [
        "55555555",
        "55555555",
        "55555555",
        "55555455",
        "55555555",
        "55555555",
        "54555555",
        "55555555",
    ]

    private static let wallTile = [
        "44444440",
        "44444440",
        "44444440",
        "00000000",
        "44404444",
        "44404444",
        "44404444",
        "00000000",
    ]

    private static let playerFacingRightTile = [
        "00777700",
        "07777770",
        "07777171",
        "07777777",
        "07777770",
        "00777700",
        "00700700",
        "07700770",
    ]

    private static func setTile(_ tile: Int, to rows: [String], in bank: inout TileBank) {
        for (y, row) in rows.enumerated() {
            for (x, digit) in row.enumerated() {
                bank.setPixel(tile: tile, x: x, y: y, color: digit.wholeNumberValue!)
            }
        }
    }
}
