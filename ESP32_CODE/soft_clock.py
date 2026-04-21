import time

class SoftClock:
    def __init__(self, time_str: str):
        # očekává "HH:MM"
        hour, minute = self._parse_time(time_str)
        self._start_minutes = hour * 60 + minute
        self._start_ticks = time.ticks_ms()

    def _parse_time(self, s: str):
        try:
            parts = s.split(":")
            if len(parts) != 2:
                raise ValueError

            hour = int(parts[0])
            minute = int(parts[1])

            if not (0 <= hour < 24 and 0 <= minute < 60):
                raise ValueError

            return hour, minute
        except:
            raise ValueError("Invalid time format, expected HH:MM")

    def _elapsed_minutes(self) -> int:
        delta_ms = time.ticks_diff(time.ticks_ms(), self._start_ticks)
        return delta_ms // 60000

    def get_time(self):
        total_minutes = (self._start_minutes + self._elapsed_minutes()) % (24 * 60)
        hour = total_minutes // 60
        minute = total_minutes % 60
        return hour, minute

    def get_str(self) -> str:
        h, m = self.get_time()
        return "{:02d}:{:02d}".format(h, m)
