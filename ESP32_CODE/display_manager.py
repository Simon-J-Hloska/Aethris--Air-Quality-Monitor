from machine import Pin, SPI
from sh1106_spi import SH1106_SPI
from arch_renderer import ArchRenderer

class DisplayManager:
    def __init__(self):
        self.spi = SPI(1, baudrate=4000000, sck=Pin(18), mosi=Pin(8))
        self.dc = Pin(12, Pin.OUT)
        self.cs = Pin(13, Pin.OUT)
        self.rst = Pin(11, Pin.OUT)
        
        self.driver = SH1106_SPI(123, 64, self.spi, self.dc, self.cs, self.rst)
        self.renderer = ArchRenderer(self.driver)
        
        self.last_sensor_data = {}
        self.last_wifi_status = {}
        
    def update_sensors(self, data_dict):
        self.last_sensor_data = data_dict
        self.renderer.update_data(
            temp=data_dict.get('temperature', 0),
            co2=data_dict.get('co2', 0),
            hum=data_dict.get('humidity', 0)
        )
        
    def update_wifi(self, connected, ip="", ssid=""):
        self.last_wifi_status = {
            'connected': connected,
            'ip': "",  # Neukládám IP
            'ssid': ssid
        }
        
    def set_time(self, clock_instance):
        """Nastavit čas z Flutteru"""
        self.renderer.set_time_string(clock_instance)
        
    def log(self, message):
        pass
        
    def refresh(self):
        self.renderer.render(self.last_sensor_data, self.last_wifi_status)
