import network
import socket
import ujson
import time
import machine
import config

# Import your sensor classes
from MHZ19_reading import MHZ19
from BME680_reading import BME680
from DataSaver import DataSaver
from display_manager import DisplayManager
from soft_clock import SoftClock

# Configuration
AP_SSID = "Aethris_Wifi_Setup"
AP_PASSWORD = "12345678"
SERVER_PORT = 80
FIRMWARE_VERSION = "1.0.0"

# Global state
wifi_connected = False
station_ip = ""
wifi_ssid = ""
wifi_password = ""
wifi_connect_pending = False  # Flag for background connection
udp_sock = None
last_udp = 0
wifi_state = "idle"   # idle | connecting | connected | failed
wifi_start_time = 0
data_saver = DataSaver(save_interval=60)
display = None
last_display_refresh = 0
real_time = time.time()

# Sensor data storage
sensor_data = {
    "temperature": 0.0,
    "humidity": 0.0,
    "pressure": 0.0,
    "co2": 0,
    "gas_resistance": 0,
    "timestamp": 0
}

AUTO_READ_INTERVAL = 15        # seconds, used only when app is NOT reading
ONLINE_READ_INTERVAL = 10      # expected app read interval
OFFLINE_GRACE = 25             # if no external read in this many seconds → we're offline
last_auto_read_time = 0
last_external_read_time = 0
sensor_read_lock = False       # prevent simultaneous reads

# Initialize sensors using your classes
mh = None
bme = None

def init_display():
    """Inicializace displaye - VOLAT JAKO PRVNÍ"""
    global display
    try:
        display = DisplayManager()
        display.log("boot sequence...")
        display.log("display initialized")
        print("Display initialized")
    except Exception as e:
        print(f"Display init failed: {e}")


def init_sensors():
    """Initialize sensors with your classes"""
    global mh, bme
    
    try:
        mh = MHZ19(tx=config.tx, rx=config.rx)
        print("MH-Z19 initialized")
    except Exception as e:
        print(f"MH-Z19 init failed: {e}")
    
    try:
        bme = BME680(scl=config.scl, sda=config.sda, address=config.address)
        print("BME680 initialized")
    except Exception as e:
        print(f"BME680 init failed: {e}")
        
            
def refresh_display():
    """Refresh display max 10x za sekundu"""
    global last_display_refresh
    
    if not display:
        return
        
    now = time.ticks_ms()
    if time.ticks_diff(now, last_display_refresh) > 100:  # 100ms = 10 FPS
        display.refresh()
        last_display_refresh = now

def read_sensors():
    """Read data from all sensors using your methods"""
    global sensor_data
    
    try:
        # Read BME680 data
        if bme:
            try:
                temp = bme.read_temperature()
                hum = bme.read_humidity()
                press = bme.read_pressure()
                gas = bme.read_gas_resistance()
                
                # Only update if values are valid (not None)
                if temp is not None:
                    sensor_data["temperature"] = round(temp, 2)
                if hum is not None:
                    sensor_data["humidity"] = round(hum, 2)
                if press is not None:
                    sensor_data["pressure"] = round(press, 2)
                if gas is not None:
                    sensor_data["gas_resistance"] = int(gas)
            except Exception as e:
                print(f"BME680 read error: {e}")
        
        # Read MH-Z19 CO2
        if mh:
            try:
                co2_value = mh.read_co2()
                if co2_value is not None and co2_value > 0:
                    sensor_data["co2"] = int(co2_value)
            except Exception as e:
                print(f"MH-Z19 read error: {e}")
        
        sensor_data["timestamp"] = int(time.time())

        # Persist min/max
        data_saver.update(sensor_data)
        
        if display:
            display.update_sensors(sensor_data)
            display.log(f"read: CO2={sensor_data['co2']} T={sensor_data['temperature']:.1f}")
        
    except Exception as e:
        print(f"Sensor read error: {e}")

def load_wifi_config():
    """Load WiFi configuration from file"""
    global wifi_ssid, wifi_password
    try:
        with open("wifi_config.json", "r") as f:
            config_data = ujson.load(f)
            wifi_ssid = config_data.get("ssid", "")
            wifi_password = config_data.get("password", "")
            print(f"Loaded WiFi config: {wifi_ssid}")
    except:
        print("No saved WiFi config")

def save_wifi_config(ssid, password):
    """Save WiFi configuration to file"""
    try:
        config_data = {"ssid": ssid, "password": password}
        with open("wifi_config.json", "w") as f:
            ujson.dump(config_data, f)
        print("WiFi config saved")
    except Exception as e:
        print(f"Failed to save WiFi config: {e}")

def setup_ap():
    """Setup Access Point"""
    ap = network.WLAN(network.AP_IF)
    ap.active(True)
    ap.config(essid=AP_SSID, password=AP_PASSWORD)
    
    print("Access Point started")
    print(f"SSID: {AP_SSID}")
    print(f"Password: {AP_PASSWORD}")
    print(f"IP: {ap.ifconfig()[0]}")
    return ap

def connect_wifi():
    global wifi_connected, station_ip
    
    if not wifi_ssid:
        broadcast_status(False)
        return False

    # Disable AP temporarily
    ap = network.WLAN(network.AP_IF)
    ap_was_active = ap.active()
    ap.active(False)
    time.sleep(0.5)
    
    # Reset STA rozhraní
    sta = network.WLAN(network.STA_IF)
    sta.active(False)
    time.sleep(0.5)
    sta.active(True)
    time.sleep(0.5)

    print(f"Connecting to {wifi_ssid}...")
    try:
        sta.connect(wifi_ssid, wifi_password)
    except OSError as e:
        print("WiFi driver error:", e)
        if ap_was_active:
            ap.active(True)
            ap.config(essid=AP_SSID, password=AP_PASSWORD)
        broadcast_status(False)
        return False

    # Wait with timeout
    max_wait = 30
    while max_wait > 0:
        if sta.isconnected():
            wifi_connected = True
            station_ip = sta.ifconfig()[0]
            print(f"Connected! IP: {station_ip}")
            if display:
                display.update_wifi(True, station_ip, wifi_ssid)
                display.log(f"wifi connected!")
            
            # Give router + phone time to reconnect
            time.sleep(2)

            # Broadcast multiple times for reliability
            for _ in range(3):
                broadcast_status(True)
                time.sleep(0.5)
            return True
        max_wait -= 1
        time.sleep(0.5)

    # ↓↓↓ FAILURE: RESTART AP ↓↓↓
    print("WiFi connection timeout - restarting AP")
    wifi_connected = False
    station_ip = ""
    
    if display:
        display.update_wifi(False, "", "")  # Clear IP
        display.log("Failed to connect to wifi..")
    
    sta.active(False)
    ap.active(True)
    ap.config(essid=AP_SSID, password=AP_PASSWORD)
    
    broadcast_status(False)  # ← Failure broadcast (AP mode)
    return False

def check_wifi_connection():
    """Check WiFi, update display status, attempt reconnect if lost."""
    global wifi_connected, station_ip

    if not wifi_connected:
        return

    sta = network.WLAN(network.STA_IF)
    if not sta.isconnected():
        print("WiFi lost — attempting reconnect...")
        wifi_connected = False
        station_ip = ""

        if display:
            display.update_wifi(False, "", "")
            display.log("WiFi ztraceno, reconnect...")

        # Single reconnect attempt before falling back to AP
        result = connect_wifi()
        if not result:
            ap = network.WLAN(network.AP_IF)
            ap.active(True)
            ap.config(essid=AP_SSID, password=AP_PASSWORD)
            broadcast_status(False)

def parse_request(request):
    """Parse HTTP request"""
    try:
        request_str = request.decode('utf-8')
        lines = request_str.split('\r\n')
        
        # Parse request line
        request_line = lines[0].split(' ')
        if len(request_line) < 2:
            return None, None, None
            
        method = request_line[0]
        path = request_line[1]
        
        # Extract body for POST requests
        body = None
        if method == 'POST':
            try:
                # Find empty line that separates headers from body
                body_index = request_str.find('\r\n\r\n')
                if body_index != -1:
                    body = request_str[body_index + 4:].strip()
                    if body:
                        print(f"POST body: {body}")
            except Exception as e:
                print(f"Error parsing body: {e}")
        
        return method, path, body
    except Exception as e:
        print(f"Error parsing request: {e}")
        return None, None, None

def handle_request(method, path, body):
    """Route and handle HTTP requests"""
    global last_external_read_time, real_time
    
    # Ping endpoint
    if path == '/ping':
        return 200, {"status": "ok"}
    
    # Sensors endpoint
    elif path in ['/sensors']:
        if method == 'POST' and body:
            global sensor_read_lock
            config_data = ujson.loads(body)
            real_time = config_data.get("time", "--:--")
            if display:
                display.set_time(real_time)

            sensor_read_lock = True
            try:
                read_sensors()
                last_external_read_time = time.time()
            finally:
                sensor_read_lock = False
            return 200, sensor_data
        elif method == 'GET':
            return 200, sensor_data
        
    elif path == '/time':
        if method == 'POST' and body:
            print(f"[TIME] Body received: {body}")
            try:
                config_data = ujson.loads(body)
                real_time = config_data.get("time", "--:--")
                clock = SoftClock(f"{real_time}")
                
                if display:
                    display.set_time(clock)
                    display.log(f"time set: {real_time}")
                    return 200, {"status": "ok", "time": real_time}
                
            except Exception as e:
                print(f"[TIME] Error: {e}")
                return 400, {"error": "invalid time format"}
    
    # Min/Max stats
    elif path == '/stats/minmax':
        if method == 'GET':
            return 200, data_saver.get_minmax()
        elif method == 'POST':
            data_saver.reset()
            return 200, {"status": "reset"}
    
    elif path == '/health':
        ap = network.WLAN(network.AP_IF)
        health_data = {
            "version": FIRMWARE_VERSION,
            "uptime": time.time(),
            "freeHeap": machine.mem_free(),
            "wifiConnected": wifi_connected,
            "apActive": ap.active()
        }
        return 200, health_data
    
    # WiFi configuration
    elif path == '/wifi':
        if method == 'POST' and body:
            print(f"[DEBUG] Body received: {body}")
            try:
                config_data = ujson.loads(body)
                ssid = config_data.get("ssid")
                password = config_data.get("password")

                if not ssid or not password:
                    return 400, {"error": "Missing SSID or password"}

                global wifi_ssid, wifi_password, wifi_connect_pending
                wifi_ssid = ssid
                wifi_password = password
                save_wifi_config(ssid, password)

                print("WiFi credentials saved, starting background connection...")

                wifi_connect_pending = True

                return 200, {
                    "status": "connecting",
                    "message": "WiFi credentials saved, connecting in background"
                }

            except Exception as e:
                print(f"Error processing WiFi config: {e}")
                return 400, {"error": "Invalid JSON"}

        else:
            return 400, {"error": "POST with JSON body required"}

        
    # WiFi status
    elif path == '/wifi/status':
        if method == 'GET':
            response = {"connected": wifi_connected}
            if wifi_connected:
                response["ip"] = station_ip
                response["port"] = str(SERVER_PORT)
                response["ssid"] = wifi_ssid
            else:
                response["ip"] = ""
                response["port"] = ""
                response["message"] = "Not connected to WiFi"
            return 200, response
    
    # Not found
    return 404, {"error": "Not found"}

def http_response(status_code, data):
    """Build HTTP response"""
    status_text = {
        200: "OK",
        204: "No Content",
        400: "Bad Request",
        404: "Not Found",
        405: "Method Not Allowed"
    }
    
    response = f"HTTP/1.1 {status_code} {status_text.get(status_code, 'Unknown')}\r\n"
    response += "Content-Type: application/json\r\n"
    response += "Access-Control-Allow-Origin: *\r\n"
    response += "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
    response += "Access-Control-Allow-Headers: Content-Type\r\n"
    response += "\r\n"
    
    if status_code != 204:  # No content for 204
        response += ujson.dumps(data)
    
    return response.encode('utf-8')

def check_auto_read():
    """Auto-read sensors only when the app hasn't read recently (offline mode)."""
    global last_auto_read_time, last_external_read_time, sensor_read_lock

    now = time.time()

    # Don't read if app is actively reading (online mode)
    time_since_external = now - last_external_read_time
    if last_external_read_time > 0 and time_since_external < OFFLINE_GRACE:
        return  # app is reading regularly, let it drive sensor reads

    # Prevent collision
    if sensor_read_lock:
        return

    # Auto-read on interval
    if last_auto_read_time == 0:
        last_auto_read_time = now
        return

    if now - last_auto_read_time >= AUTO_READ_INTERVAL:
        print("Auto-reading sensors (offline mode)")
        read_sensors()
        last_auto_read_time = now

#main server loop
def run_server():
    global wifi_connected, wifi_connect_pending, last_external_read_time

    addr = socket.getaddrinfo('0.0.0.0', SERVER_PORT)[0][-1]
    s = socket.socket()
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(addr)
    s.listen(5)

    print(f"Server listening on port {SERVER_PORT}")

    last_conn_check = 0

    while True:
        try:
            # Background WiFi connect (from /wifi POST)
            if wifi_connect_pending:
                print("Starting background WiFi connection...")
                wifi_connect_pending = False
                connect_wifi()  # broadcast already inside

            # WiFi health check every 10s
            now = time.time()
            if now - last_conn_check > 10:
                check_wifi_connection()
                last_conn_check = now

            # Auto sensor read (only when app isn't reading)
            check_auto_read()

            # Non-blocking HTTP accept
            s.settimeout(0.1)
            try:
                cl, addr = s.accept()
                print(f"Client: {addr}")
                cl.settimeout(2.0)

                request = b''
                try:
                    while True:
                        chunk = cl.recv(1024)
                        if not chunk:
                            break
                        request += chunk
                        if b'\r\n\r\n' in request:
                            if b'POST' in request[:20]:
                                header_end = request.find(b'\r\n\r\n')
                                headers = request[:header_end].decode('utf-8')
                                content_length = 0
                                for line in headers.split('\r\n'):
                                    if line.lower().startswith('content-length:'):
                                        content_length = int(line.split(':')[1].strip())
                                        break
                                if len(request) - (header_end + 4) >= content_length:
                                    break
                            else:
                                break
                except Exception as e:
                    print(f"Recv error: {e}")

                if request:
                    method, path, body = parse_request(request)
                    if method and path:
                        print(f"{method} {path}")
                        if method == 'OPTIONS':
                            response = http_response(204, {})
                        else:
                            status, data = handle_request(method, path, body)
                            response = http_response(status, data)
                        try:
                            cl.send(response)
                        except Exception as e:
                            print(f"Send error: {e}")

                cl.close()

            except OSError as e:
                if str(e) != 'timed out':
                    print(f"Socket error: {e}")

            refresh_display()

        except Exception as e:
            print(f"Server error: {e}")
            time.sleep(1)
            
def init_udp():
    global udp_sock
    udp_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    udp_sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    udp_sock.settimeout(0)

def broadcast_status(connected):
    """Broadcast IP if connected, or 'AP_MODE' if not"""
    if not udp_sock:
        return

    try:
        if connected and station_ip:
            # Success: here's my new IP
            msg = f"ESP32_SENSOR:CONNECTED:{station_ip}:{SERVER_PORT}"
            udp_sock.sendto(msg.encode(), ('255.255.255.255', 4210))
            print(f"UDP broadcast: {msg}")
        elif not connected:
            # Failure or disconnect: I'm back on AP
            ap = network.WLAN(network.AP_IF)
            if ap.active():
                msg = f"ESP32_SENSOR:AP_MODE:{AP_SSID}"
                udp_sock.sendto(msg.encode(), ('255.255.255.255', 4210))
                print(f"UDP broadcast: {msg}")
    except Exception as e:
        print("UDP broadcast error:", e)
        
def loading_step(label, dot_index):
    if not display:
        return
    d = display.driver
    for dot in range(dot_index + 1):
        d.fill_rect(8 + dot * 14, 36, 10, 6, 1)
    d.fill_rect(0, 48, 128, 16, 0)
    d.text(label + "...", 20, 50, 1)
    d.show()

def main():
    """Main entry point"""
    global display
    print("\n" + "="*40)
    print("ESP32 Sensor Server Starting")
    print("="*40)
    
    init_display()
    
    if display:
        d = display.driver

        # ── Dobrý den splash ──────────────────────────────
        d.clear()
        d.hline(0, 20, 128, 1)        # top line
        d.text("Dobry den", 22, 26, 1) # centred (128 - 9*7 = 65 / 2 ≈ 22)
        d.hline(0, 36, 128, 1)        # bottom line
        d.show()
        time.sleep(2)

        # ── Loading screen ────────────────────────────────
        d.clear()
        d.text("Inicializace", 16, 10, 1)
        d.show()
        
    # Initialize sensors
    print("Initializing sensors...")
    loading_step("Senzory", 0)
    init_sensors()
    
    # Load saved WiFi config
    print("Loading WiFi configuration...")
    loading_step("WiFi", 1)
    load_wifi_config()
    
    # Setup Access Point (always start here)
    print("Setting up Access Point...")
    setup_ap()
    
    # Init UDP socket (always needed for discovery)
    print("Initializing UDP...")
    init_udp()
        
    # Try to connect to saved WiFi
    loading_step("Server", 2)
    if wifi_ssid:
        print("Attempting to connect to saved WiFi...")
        if connect_wifi():
            print("Auto-connected to saved WiFi")
            # broadcast_status(True)  # ← already done inside connect_wifi()
        else:
            print("Saved WiFi failed, staying in AP mode")
            broadcast_status(False)  # ← Tell app I'm in AP mode
    else:
        print("No saved WiFi, waiting for configuration...")
        broadcast_status(False)  # ← Tell app I'm in AP mode
    
    # Start server
    print("="*40)
    print("Starting HTTP server...")
    print("="*40 + "\n")
    run_server()

# Run the server
if __name__ == "__main__":
    main()
