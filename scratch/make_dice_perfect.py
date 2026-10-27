from PIL import Image

# 18x18 pixel art dice template:
# . = transparent
# B = dark outline (26, 20, 36, 255)
# W = top highlight (255, 255, 255, 255)
# T = top face ivory (245, 240, 230, 255)
# R = top red pip (230, 35, 35, 255)
# L = left face light shade (210, 204, 195, 255)
# M = left face dark shade (180, 172, 160, 255)
# D = right face shadow (150, 142, 130, 255)
# S = right face deeper shadow (120, 112, 100, 255)
# P = dark pip (40, 35, 48, 255)

palette = {
    '.': (0, 0, 0, 0),
    'B': (26, 20, 36, 255),
    'W': (255, 255, 255, 255),
    'T': (245, 240, 230, 255),
    'R': (230, 35, 35, 255),
    'L': (210, 204, 195, 255),
    'M': (180, 172, 160, 255),
    'D': (150, 142, 130, 255),
    'S': (120, 112, 100, 255),
    'P': (40, 35, 48, 255),
}

# Isometric 3D cube layout:
template = [
    "........BB........",  # 0
    "......BBWWBB......",  # 1
    "....BBWWTTTTBB....",  # 2
    "..BBWWTTTTTTTTBB..",  # 3
    ".BWWTTTTRRTTTTTDB.",  # 4
    ".BWWTTTTRRTTTTTDB.",  # 5
    ".BWWTTTTTTTTTTTDB.",  # 6
    ".BLLBBWWTTTTBBDDB.",  # 7  (top corners connect)
    ".BLLLLBBBBBDDDSSB.",  # 8
    ".BLLPLLLBDDPDDSSB.",  # 9
    ".BLMPLLLBDDPDDSSB.",  # 10
    ".BLLLLLLBDDDDDSSB.",  # 11
    ".BLLLPLLBDDPDDSSB.",  # 12
    ".BLLMPLLBDDPDDSSB.",  # 13
    "..BLLLLLBDDDSSB...",  # 14
    "....BLLLBDSSB.....",  # 15
    "......BBBB........",  # 16
    "..................",  # 17
]

# Let's adjust symmetry on template so it's a completely regular hexagon isometric projection:
# Radius = 7
# Apex at x=8,9 y=1
# Left vertex at x=1 y=5
# Right vertex at x=16 y=5
# Center junction at x=8,9 y=8
# Bottom-left at x=1 y=12
# Bottom-right at x=16 y=12
# Bottom junction at x=8,9 y=16

template_hex = [
    ".......BBBB.......",  # 0
    ".....BBWWWWBB.....",  # 1
    "...BBWWTTTTTTBB...",  # 2
    "..BWWTTTTTTTTTTB..",  # 3
    ".BWWTTTTRRTTTTTDB.",  # 4
    ".BWWTTTTRRTTTTTDB.",  # 5
    ".BWWTTTTTTTTTTTDB.",  # 6
    ".BBWWTTTTTTTTBBD..",  # 7 (recheck)
]

# Let's write a crystal-clear isometric cube geometry:
img = Image.new("RGBA", (18, 18), (0, 0, 0, 0))

# Exact 18x18 ASCII art:
lines = [
    ".......BBBB.......", # 0
    ".....BBWWWWBB.....", # 1
    "...BBWWTTTTTTBB...", # 2
    "..BBWWTTTTTTTTBB..", # 3
    ".BWWTTTTRRTTTTTDB.", # 4
    ".BWWTTTTRRTTTTTDB.", # 5
    ".BBWWTTTTTTTTBBD..", # 6
    ".BLLBBWWTTBBDDDSB.", # 7
    ".BLLLLBBBBBDDDSSB.", # 8
    ".BLLPLLLBDDPDDSSB.", # 9
    ".BLLPLLLBDDPDDSSB.", # 10
    ".BLLLLLLBDDDDDSSB.", # 11
    ".BLLLPLLBDDDDDSSB.", # 12
    ".BLLLPLLBDDPDDSSB.", # 13
    "..BBLLLLBDDPSSB...", # 14
    "....BBLLBDSSBB....", # 15
    "......BBBBBB......", # 16
    "..................", # 17
]

# Let's refine lines 6-8 and 14-16 for perfect isometric symmetry
lines_refined = [
    ".......BBBB.......", # 0
    ".....BBWWWWBB.....", # 1
    "...BBWWTTTTTTBB...", # 2
    "..BWWTTTTTTTTTDB..", # 3
    ".BWWTTTTRRTTTTTDB.", # 4
    ".BWWTTTTRRTTTTTDB.", # 5
    ".BWWTTTTTTTTTTTDB.", # 6
    ".BLLBBWWTTTTBBDDB.", # 7
    ".BLLLLBBBBBDDDDSB.", # 8
    ".BLLPLLLBDDPDDDSB.", # 9
    ".BLLPLLLBDDPDDDSB.", # 10
    ".BLLLLLLBDDDDDDSB.", # 11
    ".BLLLPLLBDDDDDDSB.", # 12
    ".BLLLPLLBDDPDDDSB.", # 13
    "..BBLLLLBDDPDDSB..", # 14
    "....BBLLBDDDSB....", # 15
    "......BBBBBB......", # 16
    "..................", # 17
]

# Let's ensure length of each line is exactly 18:
for i, l in enumerate(lines_refined):
    assert len(l) == 18, f"Row {i} has length {len(l)}"
    for j, ch in enumerate(l):
        img.putpixel((j, i), palette[ch])

img.save("assets/ui/hud/hud_dice_icon.png")
print("Saved perfect dice icon!")
