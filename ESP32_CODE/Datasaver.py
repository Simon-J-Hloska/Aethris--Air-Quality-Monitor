import ujson
import time

class DataSaver:
    FILE_NAME = "minmax.json"

    def __init__(self, save_interval=30):
        """
        save_interval = seconds between flash writes (wear protection)
        """
        self.save_interval = save_interval
        self.last_save = 0

        self.data = {
            "initialized": False,
            "temperature": {"min": 0.0, "max": 0.0},
            "humidity": {"min": 0.0, "max": 0.0},
            "pressure": {"min": 0.0, "max": 0.0},
            "co2": {"min": 0, "max": 0},
            "gas_resistance": {"min": 0, "max": 0}
        }

        self.load()

    # --------------------------------------------------
    # Load from flash
    # --------------------------------------------------
    def load(self):
        try:
            with open(self.FILE_NAME, "r") as f:
                self.data = ujson.load(f)
                print("MinMax loaded from flash")
        except:
            print("No saved MinMax data")

    # --------------------------------------------------
    # Save to flash (throttled)
    # --------------------------------------------------
    def save(self, force=False):
        now = time.time()
        if not force and (now - self.last_save < self.save_interval):
            return

        try:
            with open(self.FILE_NAME, "w") as f:
                ujson.dump(self.data, f)
            self.last_save = now
            print("MinMax saved")
        except Exception as e:
            print("MinMax save error:", e)

    # --------------------------------------------------
    # Update with new sensor reading
    # --------------------------------------------------
    def update(self, sensor_data: dict):
        """
        sensor_data example:
        {
            "temperature": 23.1,
            "humidity": 41.0,
            "pressure": 1012,
            "co2": 550,
            "gas_resistance": 12345
        }
        """

        if not self.data["initialized"]:
            for key in self.data:
                if key == "initialized":
                    continue
                val = sensor_data.get(key, 0)
                self.data[key]["min"] = val
                self.data[key]["max"] = val

            self.data["initialized"] = True
            self.save(force=True)
            return

        changed = False

        for key in self.data:
            if key == "initialized":
                continue

            val = sensor_data.get(key)
            if val is None:
                continue

            if val < self.data[key]["min"]:
                self.data[key]["min"] = val
                changed = True

            if val > self.data[key]["max"]:
                self.data[key]["max"] = val
                changed = True

        if changed:
            self.save()

    # --------------------------------------------------
    # Reset values
    # --------------------------------------------------
    def reset(self):
        self.data["initialized"] = False
        self.save(force=True)

    # --------------------------------------------------
    # Get min/max (for HTTP API)
    # --------------------------------------------------
    def get_minmax(self):
        if not self.data["initialized"]:
            return {"error": "No data available"}
        return self.data
    
    
    
    
