from soft_clock import SoftClock

class ArchRenderer:
    def __init__(self, display):
        self.d = display
        self.w = 123
        self.h = 64
        
        self.scroll_text = "010100110010101001001001010"
        self.scroll_pos = 0
        self.anim_frame = 0
        
        self.temp_hist = [0] * 35
        self.co2_hist = [0] * 35
        self.ptr = 0
        
        self.logs = []
        self.last_update_time = "none yet"
        self.ci = "00:00"
        
    def render(self, sensor_data, wifi_status):
        self.d.clear()
        
        self._draw_status_bar(wifi_status)
        self._draw_big_numbers(sensor_data)
        self._draw_mini_graphs()
        self._draw_footer()
        
        self.anim_frame = (self.anim_frame + 1) % 60
        self.scroll_pos = (self.scroll_pos + 1) % len(self.scroll_text) 
        self.d.show()
        
    def set_time_string(self, time_my):
        self.ci = time_my
        
    def _draw_status_bar(self, wifi):
        """Status bar s oddělovačem - scrolling nezasahuje do ONLINE"""
        self.d.fill_rect(0, 0, self.w, 9, 1)
        
        connected = wifi.get('connected', False)
        status = "ONLINE" if connected else "OFFLINE"
        self.d.text(status, 2, 1, 0)
        
        # ═══════════════════════════════════════════════════════
        # ODDĚLOVAČ - posunutý doprava aby byl prostor pro ONLINE
        # ═══════════════════════════════════════════════════════
        separator_x = 60
        self.d.fill_rect(separator_x, 1, 3, 7, 0)
        
        # Scrolling text začíná až za oddělovačem
        start = self.scroll_pos
        visible = ""
        for i in range(12):  # Ještě méně znaků
            idx = (start + i) % len(self.scroll_text)
            visible += self.scroll_text[idx]
            
        self.d.text(visible, separator_x + 3, 1, 0)  # +3px mezera
        
    def _draw_big_numbers(self, data):
        """Velká čísla"""
        y = 11
        
        temp = data.get('temperature', 0)
        co2 = data.get('co2', 0)
        
        self._draw_value_box(0, y, 60, 26, temp, "C", "TEMP")
        self._draw_value_box(62, y, 61, 26, co2, "p", "CO2")
        
    def _draw_value_box(self, x, y, w, h, value, unit, label):
        self.d.rect(x, y, w, h, 1)
        self.d.text(label, x + 2, y + 2, 1)
        
        if isinstance(value, float):
            val_str = f"{value:.1f}"
        else:
            val_str = str(int(value))
        
        display_str = f"{val_str} {unit}"
        self.d.text(display_str, x + 4, y + 12, 1)
        
    def _draw_mini_graphs(self):
        """Sparklines s FIXED rozsahy"""
        y = 39
        h = 12
        
        # ═══════════════════════════════════════════════════════
        # TEMP: fixed 0-40°C
        # ═══════════════════════════════════════════════════════
        self._draw_sparkline_fixed(5, y, 60, h, self.temp_hist, 0, 40)
        
        # ═══════════════════════════════════════════════════════
        # CO2: fixed 400-2000 ppm (rozumný rozsah pro indoor)
        # ═══════════════════════════════════════════════════════
        self._draw_sparkline_fixed(62, y, 61, h, self.co2_hist, 000, 2000)
        
    def _draw_sparkline_fixed(self, x, y, w, h, data, min_val, max_val):
        """Graf s fixed min/max - neautoscaling!"""
        self.d.rect(x, y, w, h, 1)
        
        if len(data) < 2:
            return
        
        range_val = max_val - min_val
        
        graph_w = w - 2
        samples = min(graph_w, len(data))
        
        ordered = list(data[self.ptr:]) + list(data[:self.ptr])
        
        for i in range(1, samples):
            # Clamp hodnoty do rozsahu
            v1 = max(min_val, min(max_val, ordered[i-1]))
            v2 = max(min_val, min(max_val, ordered[i]))
            
            x1 = x + 1 + i - 1
            # Invertované Y (0 nahoře, max dole)
            y1 = y + h - 2 - int((v1 - min_val) / range_val * (h - 4))
            x2 = x + 1 + i
            y2 = y + h - 2 - int((v2 - min_val) / range_val * (h - 4))
            
            self.d.line(x1, y1, x2, y2, 1)
            
    def _draw_footer(self):
        """Spodní lišta - last update time"""
        y = 53
        
        self.d.hline(0, y, self.w, 1)
        
        # ═══════════════════════════════════════════════════════
        # ZOBRAZIT: > last update at 20:32
        # ═══════════════════════════════════════════════════════
        msg = f"updated {self.last_update_time}"
        if len(msg) > 20:
            msg = msg[:20]
        self.d.text(f"> {msg}", 2, y + 2, 1)
            
    def update_data(self, temp, co2, hum):
        self.temp_hist[self.ptr] = int(temp)
        self.co2_hist[self.ptr] = int(co2)
        self.ptr = (self.ptr + 1) % len(self.temp_hist)
        
        # ═══════════════════════════════════════════════════════
        # Uložit čas poslední aktualizace
        # ═══════════════════════════════════════════════════════
        self.last_update_time = self.ci
        
    def add_log(self, msg):
        # Log už neukládáme, používáme jen čas poslední aktualizace
        pass
