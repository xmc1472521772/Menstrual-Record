import struct
import zlib
import math

WIDTH = 1024
HEIGHT = 1024

def rgba(r, g, b, a=255):
    return (r, g, b, a)

def lerp_color(c1, c2, t):
    t = max(0, min(1, t))
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(4))

def dist(x1, y1, x2, y2):
    return math.sqrt((x1 - x2)**2 + (y1 - y2)**2)

def smooth_step(edge0, edge1, x):
    t = max(0, min(1, (x - edge0) / (edge1 - edge0)))
    return t * t * (3 - 2 * t)

def rounded_rect_sdf(x, y, rx, ry, rw, rh, radius):
    """Signed distance function for a rounded rectangle. Negative = inside."""
    dx = max(abs(x - rx - rw / 2) - rw / 2 + radius, 0)
    dy = max(abs(y - ry - rh / 2) - rh / 2 + radius, 0)
    return math.sqrt(dx * dx + dy * dy) - radius

def heart_sdf(x, y, cx, cy, size):
    """Signed distance function for a heart shape. Negative = inside."""
    nx = (x - cx) / size
    ny = (y - cy) / size
    # Flip Y for standard heart orientation
    ny = -ny + 0.4
    val = (nx * nx + ny * ny - 1) ** 3 - nx * nx * ny * ny * ny
    return val * size * 0.3

def drop_sdf(x, y, cx, cy, size):
    """Signed distance function for a water/blood drop shape."""
    nx = (x - cx) / size
    ny = (y - cy) / size
    # Teardrop: circle bottom, pointed top
    if ny < 0:
        # Top half: pointed
        r = max(0, 1 - ny * ny * 0.6)
        return (nx * nx + ny * ny - r * r) * size
    else:
        # Bottom half: round
        return (nx * nx + (ny - 0.15) * (ny - 0.15) - 0.75) * size

def circle_sdf(x, y, cx, cy, r):
    return dist(x, y, cx, cy) - r

def generate_icon():
    pixels = bytearray(WIDTH * HEIGHT * 4)

    # ─── Color Palette (matches app) ─────────────────────────────
    bg_top    = rgba(252, 228, 236)   # #FCE4EC light pink
    bg_bottom = rgba(233, 30, 99)     # #E91E63 primary pink
    cal_body  = rgba(255, 255, 255)   # white
    cal_header = rgba(233, 30, 99)    # #E91E63
    heart_core = rgba(233, 30, 99)    # #E91E63
    heart_edge = rgba(194, 24, 91)    # #C2185B
    ring_color = rgba(244, 143, 177)  # #F48FB1 medium pink
    dot_color  = rgba(255, 255, 255, 220)

    # ─── 1. Background Gradient ──────────────────────────────────
    for y in range(HEIGHT):
        t = y / HEIGHT
        t = t * t * (3 - 2 * t)  # smoothstep
        color = lerp_color(bg_top, bg_bottom, t)
        for x in range(WIDTH):
            idx = (y * WIDTH + x) * 4
            pixels[idx:idx + 4] = bytes(color)

    # ─── 2. Calendar Body (rounded rectangle) ────────────────────
    cal_x, cal_y = 192, 160
    cal_w, cal_h = 640, 720
    cal_r = 72

    for y in range(max(0, cal_y - 5), min(HEIGHT, cal_y + cal_h + 5)):
        for x in range(max(0, cal_x - 5), min(WIDTH, cal_x + cal_w + 5)):
            d = rounded_rect_sdf(x, y, cal_x, cal_y, cal_w, cal_h, cal_r)
            idx = (y * WIDTH + x) * 4

            if d < 0:
                # Inside the rectangle
                # Subtle shadow near edges
                edge_t = smooth_step(-30, 0, d)
                color = lerp_color(rgba(240, 240, 240), cal_body, edge_t)
                pixels[idx:idx + 4] = bytes(color)
            elif d < 2.5:
                # Soft anti-aliased edge
                alpha = int(255 * (1 - d / 2.5))
                bg = tuple(pixels[idx:idx + 4])
                color = lerp_color(bg, cal_body, alpha / 255)
                pixels[idx:idx + 4] = bytes(color)

    # ─── 3. Calendar Header Bar ──────────────────────────────────
    header_h = 160
    header_y = cal_y
    for y in range(max(0, header_y), min(HEIGHT, header_y + header_h)):
        for x in range(max(0, cal_x), min(WIDTH, cal_x + cal_w)):
            d = rounded_rect_sdf(x, y, cal_x, cal_y, cal_w, cal_h, cal_r)
            idx = (y * WIDTH + x) * 4

            if d < 0:
                # Inside header area
                if y < header_y + header_h - 4:
                    pixels[idx:idx + 4] = bytes(cal_header)
                else:
                    # Slight fade at bottom of header
                    t = (y - (header_y + header_h - 4)) / 4
                    pixels[idx:idx + 4] = bytes(lerp_color(cal_header, cal_body, t))

    # ─── 4. Calendar Rings ───────────────────────────────────────
    ring_y = cal_y - 20
    ring_r_outer = 22
    ring_r_inner = 14
    for ring_x in [cal_x + 180, cal_x + cal_w - 180]:
        for y in range(max(0, ring_y - 30), min(HEIGHT, ring_y + 30)):
            for x in range(max(0, ring_x - 30), min(WIDTH, ring_x + 30)):
                d = circle_sdf(x, y, ring_x, ring_y, ring_r_outer)
                d_inner = circle_sdf(x, y, ring_x, ring_y, ring_r_inner)
                idx = (y * WIDTH + x) * 4

                if d < 0 and d_inner > 0:
                    # Ring body
                    pixels[idx:idx + 4] = bytes(heart_edge)
                elif -2 < d < 0:
                    # Outer edge AA
                    alpha = int(255 * (1 + d / 2))
                    bg = tuple(pixels[idx:idx + 4])
                    pixels[idx:idx + 4] = bytes(lerp_color(bg, heart_edge, alpha / 255))

    # ─── 5. Heart in Center ──────────────────────────────────────
    heart_cx = cal_x + cal_w // 2
    heart_cy = cal_y + header_h + (cal_h - header_h) // 2 + 40
    heart_size = 190

    for y in range(max(0, heart_cy - heart_size - 20), min(HEIGHT, heart_cy + heart_size + 20)):
        for x in range(max(0, heart_cx - heart_size - 20), min(WIDTH, heart_cx + heart_size + 20)):
            d = heart_sdf(x, y, heart_cx, heart_cy, heart_size)
            idx = (y * WIDTH + x) * 4

            if d < 0:
                # Inside heart
                t = dist(x, y, heart_cx, heart_cy) / heart_size
                color = lerp_color(heart_core, heart_edge, t * 0.6)

                # Subtle highlight on top-left
                dx = (x - heart_cx) / heart_size
                dy = (y - heart_cy) / heart_size
                highlight = max(0, 0.5 - math.sqrt(dx * dx + dy * dy)) * 0.3
                color = tuple(min(255, int(c + highlight * 80)) for c in color)

                pixels[idx:idx + 4] = bytes(color)
            elif d < 3:
                # Anti-aliased edge
                alpha = int(255 * (1 - d / 3))
                bg = tuple(pixels[idx:idx + 4])
                pixels[idx:idx + 4] = bytes(lerp_color(bg, heart_edge, alpha / 255))

    # ─── 6. Small Dots in Header ─────────────────────────────────
    dot_y = cal_y + header_h // 2
    dot_r = 10
    for i, dx in enumerate([-130, 0, 130]):
        dot_x = heart_cx + dx
        for y in range(max(0, dot_y - 18), min(HEIGHT, dot_y + 18)):
            for x in range(max(0, dot_x - 18), min(WIDTH, dot_x + 18)):
                d = circle_sdf(x, y, dot_x, dot_y, dot_r)
                idx = (y * WIDTH + x) * 4

                if d < 0:
                    pixels[idx:idx + 4] = bytes(dot_color)
                elif d < 1.5:
                    alpha = int(220 * (1 - d / 1.5))
                    bg = tuple(pixels[idx:idx + 4])
                    pixels[idx:idx + 4] = bytes(lerp_color(bg, dot_color, alpha / 255))

    # ─── 7. Calendar Grid Dots (subtle) ──────────────────────────
    grid_start_y = header_y + header_h + 40
    grid_rows = 5
    grid_cols = 7
    cell_w = cal_w // (grid_cols + 1)
    cell_h = (cal_h - header_h - 100) // (grid_rows + 1)
    grid_x_start = cal_x + cell_w // 2 + 20
    grid_dot_r = 6

    for row in range(grid_rows):
        for col in range(grid_cols):
            gx = grid_x_start + col * cell_w
            gy = grid_start_y + row * cell_h

            # Skip dots that would overlap the heart
            if dist(gx, gy, heart_cx, heart_cy) < heart_size + 30:
                continue

            # Some dots are pink (period days), others are light gray
            if (row + col) % 3 == 0:
                dot_c = rgba(233, 30, 99, 100)  # subtle pink
            else:
                dot_c = rgba(200, 200, 200, 80)  # very light gray

            for y in range(max(0, gy - grid_dot_r - 2), min(HEIGHT, gy + grid_dot_r + 2)):
                for x in range(max(0, gx - grid_dot_r - 2), min(WIDTH, gx + grid_dot_r + 2)):
                    d = circle_sdf(x, y, gx, gy, grid_dot_r)
                    if d < 0:
                        idx = (y * WIDTH + x) * 4
                        bg = tuple(pixels[idx:idx + 4])
                        pixels[idx:idx + 4] = bytes(lerp_color(bg, dot_c, dot_c[3] / 255))

    # ─── Encode PNG ──────────────────────────────────────────────
    def create_png(width, height, rgba_data):
        def chunk(chunk_type, data):
            c = chunk_type + data
            crc = struct.pack('>I', zlib.crc32(c) & 0xffffffff)
            return struct.pack('>I', len(data)) + c + crc

        sig = b'\x89PNG\r\n\x1a\n'
        ihdr_data = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)
        ihdr = chunk(b'IHDR', ihdr_data)

        raw_data = bytearray()
        for y in range(height):
            raw_data.append(0)
            row_start = y * width * 4
            raw_data.extend(rgba_data[row_start:row_start + width * 4])

        compressed = zlib.compress(bytes(raw_data), 9)
        idat = chunk(b'IDAT', compressed)
        iend = chunk(b'IEND', b'')

        return sig + ihdr + idat + iend

    png_data = create_png(WIDTH, HEIGHT, pixels)

    with open(r'E:\yimaflutter\assets\icon\app_icon.png', 'wb') as f:
        f.write(png_data)

    print(f'Icon generated: {len(png_data)} bytes')

if __name__ == '__main__':
    generate_icon()
