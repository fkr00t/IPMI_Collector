# IPMI Collector untuk Prometheus

Sistem monitoring IPMI custom menggunakan `ipmitool` yang kompatibel dengan Prometheus dan Grafana Dashboard custom.

## 🚀 Fitur

- **Multi-Server Monitoring**: Support untuk 12+ server dengan kredensial berbeda
- **Custom Metrics**: Temperature, Voltage, Fan Speed, Power Consumption, dan Sensor State
- **Prometheus Compatible**: Format metrics yang sesuai dengan Prometheus
- **Custom Grafana Dashboard**: Dashboard custom dengan template variable untuk multi-server
- **Robust Error Handling**: Timeout dan error handling yang baik
- **HTTP Endpoint**: Endpoint `/metrics` untuk Prometheus scraping

## 📁 Struktur File

```
IPMI_Collector/
├── ipmi_collector.sh                    # Script utama collector
├── prometheus.yml                       # Konfigurasi target Prometheus
├── dashboard-ipmi-bmc-monitoring.json   # Dashboard Grafana custom
└── README.md                            # Dokumentasi ini
```

## 🛠️ Instalasi

### Prerequisites

```bash
# Install ipmitool
sudo apt-get install ipmitool    # Ubuntu/Debian
sudo yum install OpenIPMI-tools  # CentOS/RHEL
sudo dnf install OpenIPMI-tools  # Fedora

# Install Python3 (untuk HTTP server)
sudo apt-get install python3     # Ubuntu/Debian
sudo yum install python3         # CentOS/RHEL
sudo dnf install python3         # Fedora
```

### Setup

1. **Clone repository**
```bash
git clone https://github.com/fkr00t/IPMI_Collector.git
cd IPMI_Collector
```

2. **Konfigurasi server**
Edit file `ipmi_collector.sh` dan sesuaikan konfigurasi server:

```bash
declare -A SERVERS=(
    ["SERVER-NAME"]="IP:USERNAME:PASSWORD"
    # Tambahkan server lainnya
)
```

3. **Jalankan collector**
```bash
chmod +x ipmi_collector.sh
./ipmi_collector.sh
```

## ⚙️ Konfigurasi

### Server Configuration

Edit bagian `SERVERS` di `ipmi_collector.sh`:

```bash
declare -A SERVERS=(
    ["GG-HCI-N1"]="10.206.31.11:admin:admin"
    ["GG-HCI-N2"]="10.206.31.12:admin:admin"
    ["SM-GPU1"]="10.206.31.35:ADMIN:Admin123!"
    # Tambahkan server sesuai kebutuhan
)
```

### Prometheus Configuration

Tambahkan konfigurasi berikut ke `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'ipmi-custom'
    static_configs:
      - targets:
        - 'YOUR_COLLECTOR_IP:8000'
    scrape_interval: 30s
    scrape_timeout: 25s
    metrics_path: /metrics
```

## 📊 Metrics yang Tersedia

| Metric Name | Type | Description |
|-------------|------|-------------|
| `ipmi_temperature_celsius` | Gauge | Temperature dalam Celsius |
| `ipmi_voltage_volts` | Gauge | Voltage dalam Volts |
| `ipmi_fan_speed_rpm` | Gauge | Kecepatan fan dalam RPM |
| `ipmi_power_watts` | Gauge | Konsumsi daya dalam Watts |
| `ipmi_sensor_state` | Gauge | Status sensor (0=OK, 1=Warning, 2=Critical) |
| `ipmi_bmc_info` | Gauge | Informasi BMC untuk template variable |

## 🔧 Penggunaan

### Menjalankan sebagai Service

1. **Buat systemd service**
```bash
sudo nano /etc/systemd/system/ipmi-collector.service
```

2. **Isi dengan konfigurasi berikut**
```ini
[Unit]
Description=IPMI Collector for Prometheus
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/path/to/IPMI_Collector
ExecStart=/path/to/IPMI_Collector/ipmi_collector.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

3. **Enable dan start service**
```bash
sudo systemctl daemon-reload
sudo systemctl enable ipmi-collector
sudo systemctl start ipmi-collector
```

### Monitoring

- **HTTP Endpoint**: `http://YOUR_IP:8000/metrics`
- **Logs**: Check dengan `journalctl -u ipmi-collector`
- **Status**: `systemctl status ipmi-collector`

## 🎯 Grafana Dashboard Custom

Sistem ini dilengkapi dengan **Dashboard Grafana Custom** yang sudah dioptimalkan untuk monitoring IPMI BMC.

### Fitur Dashboard Custom

- **Template Variable**: Dropdown untuk memilih server (`$HOST`)
- **Multi-Panel Layout**: 
  - Temperature (Stat panel dengan threshold)
  - Fan Speed (Gauge dengan color coding)
  - Power Consumption (Gauge dengan threshold)
  - Voltage (Stat panel)
- **Threshold Configuration**: 
  - Temperature: Green < 60°C, Yellow 60-80°C, Red > 80°C
  - Fan Speed: Red < 1000 RPM, Yellow 1000-3000 RPM, Green 3000-8000 RPM, Blue > 8000 RPM
  - Power: Green < 500W, Yellow 500-800W, Red > 800W
- **Auto-refresh**: Template variable refresh setiap kali dashboard di-load

### Setup Dashboard

1. **Import Dashboard**
   - Buka Grafana
   - Klik "+" → "Import"
   - Upload file `dashboard-ipmi-bmc-monitoring.json`
   - Atau copy-paste JSON content

2. **Konfigurasi Data Source**
   - Pastikan Prometheus data source sudah dikonfigurasi
   - Update `uid` data source jika diperlukan (default: `feh0gtg9lkhs0e`)

3. **Template Variable**
   - Dashboard menggunakan variable `$HOST` untuk memilih server
   - Variable otomatis ter-populate dari metric `ipmi_bmc_info`
   - Regex: `.*exported_instance="([^"]+)".*`

### Dashboard Panels

| Panel | Type | Metric | Description |
|-------|------|--------|-------------|
| Temperature | Stat | `ipmi_temperature_celsius` | Temperature dengan threshold color coding |
| Fan Speed | Gauge | `ipmi_fan_speed_rpm` | Kecepatan fan dengan RPM threshold |
| Power Consumption | Gauge | `ipmi_power_watts` | Konsumsi daya dengan watt threshold |
| Voltage | Stat | `ipmi_voltage_volts` | Voltage monitoring |

### Customization

Untuk menyesuaikan dashboard:

1. **Threshold Values**: Edit nilai threshold di field config setiap panel
2. **Colors**: Ubah warna threshold sesuai kebutuhan
3. **Layout**: Sesuaikan grid position dan size panel
4. **Time Range**: Default 6 jam, dapat diubah di time picker

## 🔒 Keamanan

### Best Practices

1. **Kredensial**: Simpan password di environment variables atau file terpisah
2. **Network**: Batasi akses ke port 8000 hanya dari Prometheus server
3. **Firewall**: Konfigurasi firewall untuk membatasi akses IPMI
4. **Monitoring**: Monitor log untuk aktivitas mencurigakan

### Contoh Konfigurasi Kredensial yang Aman

```bash
# Gunakan environment variables
export IPMI_PASSWORD="your_password"
declare -A SERVERS=(
    ["SERVER-NAME"]="IP:USERNAME:${IPMI_PASSWORD}"
)
```

## 🐛 Troubleshooting

### Common Issues

1. **ipmitool not found**
   ```bash
   sudo apt-get install ipmitool
   ```

2. **Connection timeout**
   - Periksa konektivitas network
   - Pastikan IPMI service aktif di server target
   - Cek kredensial username/password

3. **Permission denied**
   ```bash
   chmod +x ipmi_collector.sh
   sudo ./ipmi_collector.sh
   ```

4. **Port 8000 already in use**
   - Ganti port di variabel `COLLECTOR_PORT`
   - Atau kill process yang menggunakan port tersebut

### Debug Mode

Tambahkan debug logging dengan mengedit script:

```bash
# Tambahkan di awal script
set -x  # Enable debug mode
```

## 📈 Performance

- **Collection Interval**: 30 detik (dapat disesuaikan)
- **Timeout**: 30 detik per server
- **Memory Usage**: ~10-50MB tergantung jumlah server
- **CPU Usage**: Minimal, hanya saat collection

## 🤝 Contributing

1. Fork repository
2. Buat feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add some AmazingFeature'`)
4. Push ke branch (`git push origin feature/AmazingFeature`)
5. Buat Pull Request

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/fkr00t/IPMI_Collector/issues)
- **Documentation**: [Wiki](https://github.com/fkr00t/IPMI_Collector/wiki)

---

**Note**: Pastikan untuk mengganti placeholder IP dan kredensial sesuai dengan environment Anda sebelum deployment. 