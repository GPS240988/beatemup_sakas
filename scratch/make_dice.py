from PIL import Image

# Create 18x18 pixel art dice
# An isometric 3D die:
# Top face showing pips, Left face showing pips, Right face showing pips.
# Or slightly tilted 3D cube.
img = Image.new("RGBA", (18, 18), (0, 0, 0, 0))

# Color palette:
# Outline: (22, 18, 30, 255)
# Top face: (252, 250, 242, 255)
# Top face highlight: (255, 255, 255, 255)
# Left face: (218, 212, 202, 255)
# Left face shadow: (185, 178, 168, 255)
# Right face: (160, 152, 142, 255)
# Right face shadow: (130, 122, 114, 255)
# Red pip: (220, 35, 35, 255)
# Dark pip: (35, 30, 42, 255)
# Dark pip soft: (55, 48, 65, 255)

OUT = (22, 18, 30, 255)
TOP = (250, 248, 240, 255)
TOP_HI = (255, 255, 255, 255)
LEFT = (212, 206, 196, 255)
RIGHT = (155, 148, 140, 255)
PIP_DARK = (30, 26, 38, 255)
PIP_RED = (225, 40, 40, 255)

# Pixel map (18 rows, 18 cols):
# Let's map an isometric cube:
# Apex at (8, 2), (9, 2)
pixels = {
    # Top face outline
    (8, 1): OUT, (9, 1): OUT,
    (6, 2): OUT, (7, 2): OUT, (10, 2): OUT, (11, 2): OUT,
    (4, 3): OUT, (5, 3): OUT, (12, 3): OUT, (13, 3): OUT,
    (2, 4): OUT, (3, 4): OUT, (14, 4): OUT, (15, 4): OUT,
    (1, 5): OUT, (16, 5): OUT,
    (1, 6): OUT, (16, 6): OUT,
    
    # Left vertical edge
    (1, 7): OUT, (1, 8): OUT, (1, 9): OUT, (1, 10): OUT, (1, 11): OUT,
    # Right vertical edge
    (16, 7): OUT, (16, 8): OUT, (16, 9): OUT, (16, 10): OUT, (16, 11): OUT,
    
    # Center vertical ridge from middle down
    # Top face bottom corner meets at (8, 9), (9, 9)
    # Center ridge goes from (8, 10) down to (8, 16)
    (8, 10): OUT, (9, 10): OUT,
    (8, 11): OUT, (9, 11): OUT,
    (8, 12): OUT, (9, 12): OUT,
    (8, 13): OUT, (9, 13): OUT,
    (8, 14): OUT, (9, 14): OUT,
    (8, 15): OUT, (9, 15): OUT,
    (8, 16): OUT, (9, 16): OUT,

    # Bottom left edge
    (2, 12): OUT, (3, 12): OUT,
    (4, 13): OUT, (5, 14): OUT,
    (6, 15): OUT, (7, 16): OUT,
    
    # Bottom right edge
    (15, 12): OUT, (14, 12): OUT,
    (13, 13): OUT, (12, 14): OUT,
    (11, 15): OUT, (10, 16): OUT,
}

# Instead of hardcoding loose lines, let's draw a super clean 3D isometric box!
# Let's write an algorithm that renders:
# Top face: y from 2 to 8. Width expands from apex (8.5, 2) down to left corner (2, 5.5) and right corner (15, 5.5), then narrows to center (8.5, 9).
# Left face: polygon [(2, 6), (8, 9), (8, 16), (2, 12)]
# Right face: polygon [(9, 9), (15, 6), (15, 12), (9, 16)]

grid = [[(0, 0, 0, 0) for _ in range(18)] for _ in range(18)]

# Let's define the faces explicitly:
# Top face rows:
# row 2: x 8..9
# row 3: x 6..11
# row 4: x 4..13
# row 5: x 2..15
# row 6: x 3..14
# row 7: x 5..12
# row 8: x 7..10
# row 9: x 8..9
for x in range(8, 10): grid[2][x] = TOP
for x in range(6, 12): grid[3][x] = TOP
for x in range(4, 14): grid[4][x] = TOP
for x in range(3, 15): grid[5][x] = TOP
for x in range(4, 14): grid[6][x] = TOP
for x in range(6, 12): grid[7][x] = TOP
for x in range(7, 11): grid[8][x] = TOP
for x in range(8, 10): grid[9][x] = TOP

# Pips on top face: Red single pip (classic Japanese arcade die "Ace" in center) or 3 pips
# Let's put a distinct 1 red pip in center (row 5-6, col 8-9) or 3 black pips:
# A big red central dot is extremely readable at 16x16:
grid[5][8] = PIP_RED
grid[5][9] = PIP_RED
grid[6][8] = PIP_RED
grid[6][9] = PIP_RED

# Left face (x: 2..8, y: 6..16)
for y in range(6, 17):
    for x in range(2, 9):
        # Check if inside left polygon
        # left bound: x=2 at y=6..12, then slopes to x=8 at y=16
        # right bound: x=8 at y=9..16, and slopes from x=3 at y=6 to x=8 at y=9
        top_bound = 5 + int((x - 2) * 0.5)
        bottom_bound = 12 + int((x - 2) * 0.67)
        if top_bound < y <= bottom_bound and x < 9:
            grid[y][x] = LEFT

# Right face (x: 9..16, y: 6..17)
for y in range(6, 17):
    for x in range(9, 16):
        top_bound = 5 + int((15 - x) * 0.5)
        bottom_bound = 12 + int((15 - x) * 0.67)
        if top_bound < y <= bottom_bound:
            grid[y][x] = RIGHT

# Left face pips (e.g. 2 pips):
grid[9][4] = PIP_DARK
grid[10][4] = PIP_DARK
grid[13][6] = PIP_DARK
grid[14][6] = PIP_DARK

# Right face pips (e.g. 3 pips or 4 pips):
grid[9][11] = PIP_DARK
grid[9][14] = PIP_DARK
grid[13][11] = PIP_DARK
grid[13][14] = PIP_DARK

# Center divider:
for y in range(9, 17):
    grid[y][8] = OUT

# Now outline: any pixel that is non-empty and has an empty neighbor, or 1px outside non-empty
out_grid = [[(0, 0, 0, 0) for _ in range(18)] for _ in range(18)]
for y in range(18):
    for x in range(18):
        if grid[y][x][3] > 0:
            out_grid[y][x] = grid[y][x]

# Add border around filled pixels
final_grid = [[out_grid[y][x] for x in range(18)] for y in range(18)]
for y in range(18):
    for x in range(18):
        if out_grid[y][x][3] == 0:
            # check neighbors
            has_filled_neighbor = False
            for dy, dx in [(-1,0), (1,0), (0,-1), (0,1)]:
                ny, nx = y + dy, x + dx
                if 0 <= ny < 18 and 0 <= nx < 18:
                    if out_grid[ny][nx][3] > 0 and out_grid[ny][nx] != OUT:
                        has_filled_neighbor = True
                        break
            if has_filled_neighbor:
                final_grid[y][x] = OUT

# Also ensure top ridge has highlight
for x in range(7, 11):
    if final_grid[3][x] == TOP:
        final_grid[3][x] = TOP_HI

for y in range(18):
    for x in range(18):
        img.putpixel((x, y), final_grid[y][x])

img.save("assets/ui/hud/hud_dice_icon.png")
print("Saved assets/ui/hud/hud_dice_icon.png successfully")
