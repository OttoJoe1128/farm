import { ParcelFeature, CanonicalAsset, WorkOrder } from '../types';

export const EDIRNE_PARCEL: ParcelFeature = {
  type: 'Feature',
  geometry: {
    type: 'Polygon',
    coordinates: [
      [
        [26.57218, 41.62103],
        [26.57211, 41.62103],
        [26.57181, 41.62104],
        [26.57162, 41.62104],
        [26.57143, 41.62104],
        [26.57111, 41.62104],
        [26.57111, 41.62065],
        [26.57199, 41.62063],
        [26.57198, 41.6208],
        [26.57197, 41.62087],
        [26.57201, 41.62091],
        [26.57204, 41.62095],
        [26.57207, 41.62098],
        [26.57218, 41.62103],
      ],
    ],
  },
  properties: {
    ParselNo: '835',
    Alan: '3.330,87 m²',
    Mevkii: 'Köyiçi',
    Nitelik: 'Tarla',
    Ada: '103',
    Il: 'Edirne',
    Ilce: 'Merkez',
    Pafta: 'E17-D-12-D-2',
    Mahalle: 'Bosna',
    name: 'Edirne Bosna 103/835',
  },
};

export const MILAS_PARCEL: ParcelFeature = {
  type: 'Feature',
  geometry: {
    type: 'Polygon',
    coordinates: [
      [
        [27.73865, 37.39859],
        [27.73884, 37.39881],
        [27.73876, 37.39887],
        [27.73875, 37.39883],
        [27.73869, 37.39884],
        [27.73859, 37.39891],
        [27.7384, 37.39883],
        [27.73839, 37.39872],
        [27.73849, 37.39866],
        [27.73853, 37.3986],
        [27.73865, 37.39859],
      ],
    ],
  },
  properties: {
    ParselNo: '1073',
    Alan: '1.092,58 m²',
    Mevkii: 'Sarıcayer',
    Nitelik: 'Zeytinlik',
    Ada: '204',
    Il: 'Muğla',
    Ilce: 'Milas',
    Pafta: 'N19.A.15.B.2.A',
    Mahalle: 'Çomakdağ Kızılağaç',
    name: 'Milas Çomakdağ 204/1073',
  },
};

export const INITIAL_ASSETS: CanonicalAsset[] = [
  {
    asset_id: 'asset_tree_001',
    name: 'Ağaç No #14 (Ceviz)',
    type: 'Point',
    geometry: {
      type: 'Point',
      coordinates: [26.57145, 41.62085],
    },
    style: {
      color: '#22c55e',
      icon: 'agac',
    },
    properties: {
      iot_connected: false,
      local_x_m: 28.5,
      local_y_m: -21.2,
      local_origin: 'parcel_first_vertex',
      digital_card: {
        genel: {
          asset_code: 'SF-AGAC-014',
          notes: 'Aşı tutumu mükemmel, sürgün gelişimi kuvvetli.',
        },
        agac: {
          species: 'Ceviz (Juglans regia)',
          variety: 'Chandler',
          age_years: '4',
          planting_date: '2022-03-20',
          rootstock: 'Klasik Ceviz Çöğürü',
          row_no: '2',
          tree_no: '14',
          ndvi_score: 0.84,
        },
        saglik: {
          disease_name: 'Yok',
          symptoms: 'Yaprak ayası ve renk tonu homojen yeşil, antraknoz yok.',
          severity: 'Düşük',
          treatment_plan: 'İlkbahar bordo bulamacı uygulandı',
        },
        bakim: {
          last_irrigation_at: '2026-10-21T08:00:00Z',
          last_fertilization_at: '2026-10-10T14:30:00Z',
          last_pruning_at: '2026-02-18',
          last_spray_at: '2026-04-05',
        },
        uretim: {
          last_yield_kg: '32',
          expected_yield_kg: '48',
          fruit_count_est: '210',
        },
      },
      timestamps: {
        created_at: '2026-03-01T10:00:00Z',
        updated_at: '2026-10-24T03:00:00Z',
        last_operation: 'asset_loaded',
      },
    },
  },
  {
    asset_id: 'asset_tree_002',
    name: 'Ağaç No #15 (Ceviz)',
    type: 'Point',
    geometry: {
      type: 'Point',
      coordinates: [26.57165, 41.62085],
    },
    style: {
      color: '#22c55e',
      icon: 'agac',
    },
    properties: {
      iot_connected: false,
      local_x_m: 44.2,
      local_y_m: -21.0,
      local_origin: 'parcel_first_vertex',
      digital_card: {
        genel: {
          asset_code: 'SF-AGAC-015',
          notes: 'Yan dal oluşumu dengeli, taç çapı 2.8 metre.',
        },
        agac: {
          species: 'Ceviz (Juglans regia)',
          variety: 'Chandler',
          age_years: '4',
          planting_date: '2022-03-20',
          rootstock: 'Klasik Ceviz Çöğürü',
          row_no: '2',
          tree_no: '15',
          ndvi_score: 0.81,
        },
        saglik: {
          disease_name: 'Yok',
          symptoms: 'Gövde kabuğu pürüzsüz',
          severity: 'Düşük',
          treatment_plan: 'Rutin',
        },
        bakim: {
          last_irrigation_at: '2026-10-21T08:00:00Z',
        },
        uretim: {
          last_yield_kg: '35',
          expected_yield_kg: '50',
        },
      },
      timestamps: {
        created_at: '2026-03-01T10:00:00Z',
        updated_at: '2026-10-24T03:00:00Z',
      },
    },
  },
  {
    asset_id: 'asset_well_001',
    name: 'Derin Kuyu & Pompa İstasyonu',
    type: 'Point',
    geometry: {
      type: 'Point',
      coordinates: [26.57135, 41.62072],
    },
    style: {
      color: '#0284c7',
      icon: 'kuyu',
    },
    properties: {
      iot_connected: true,
      local_x_m: 20.1,
      local_y_m: -35.6,
      local_origin: 'parcel_first_vertex',
      digital_card: {
        genel: {
          asset_code: 'SF-KUYU-001',
          notes: '140 metre derin sondaj dalgıç pompa (15 kW / 20 HP). Otomatik hidrofor ve frekans invertörü kontrollü.',
        },
        well_pump: {
          well_depth_m: 140,
          static_water_level_m: 48.5,
          dynamic_water_level_m: 64.2,
          flow_rate_m3_h: 46.5,
          daily_volume_m3: 312.0,
          line_pressure_bar: 4.8,
          motor_power_kw: 15.0,
          motor_current_a: 28.6,
          motor_voltage_v: 380,
          motor_status: 'calisiyor',
          dry_run_protection_ok: true,
        },
        iot: {
          air_temperature_c: 21.0,
          battery_pct: 98,
          signal_dbm: -58,
          last_seen_at: '2026-10-24T03:30:00Z',
        },
        bakim: {
          last_irrigation_at: '2026-10-24T02:00:00Z',
        },
      },
      timestamps: {
        created_at: '2026-02-15T09:00:00Z',
        updated_at: '2026-10-24T03:30:00Z',
      },
    },
  },
  {
    asset_id: 'asset_sensor_001',
    name: 'IoT Toprak Nem & Hava Sensörü (Zone 1)',
    type: 'Point',
    geometry: {
      type: 'Point',
      coordinates: [26.57175, 41.62075],
    },
    style: {
      color: '#ea580c',
      icon: 'sensor',
    },
    properties: {
      iot_connected: true,
      local_x_m: 52.3,
      local_y_m: -32.1,
      local_origin: 'parcel_first_vertex',
      digital_card: {
        genel: {
          asset_code: 'SF-IOT-001',
          notes: 'LoRaWAN protokolü ile bağlı 4 derinlikli profil sensörü (20cm, 50cm, 80cm) ve mikroklima istasyonu.',
        },
        iot: {
          soil_moisture_pct: 22.4,
          soil_moisture_deep_pct: 28.6,
          trunk_temperature_c: 21.5,
          air_temperature_c: 24.8,
          air_humidity_pct: 51,
          soil_ph: 6.85,
          soil_ec: 1.25,
          battery_pct: 91,
          signal_dbm: -74,
          last_seen_at: '2026-10-24T03:35:00Z',
        },
        alarm: {
          soil_moisture_min: 20,
          soil_moisture_max: 40,
          air_temperature_min: 2,
          air_temperature_max: 38,
        },
      },
      timestamps: {
        created_at: '2026-04-10T12:00:00Z',
        updated_at: '2026-10-24T03:35:00Z',
      },
    },
  },
  {
    asset_id: 'asset_solar_001',
    name: 'Güneş Paneli Sistemi (30 kWp GES)',
    type: 'Point',
    geometry: {
      type: 'Point',
      coordinates: [26.57188, 41.62092],
    },
    style: {
      color: '#eab308',
      icon: 'gunes',
    },
    properties: {
      iot_connected: true,
      local_x_m: 62.4,
      local_y_m: -13.2,
      local_origin: 'parcel_first_vertex',
      digital_card: {
        genel: {
          asset_code: 'SF-SOLAR-001',
          notes: 'Kuyu pompası ve saha otomasyonu için monokristal panel dizisi ve 30kW üç fazlı MPPT invertör.',
        },
        solar: {
          current_power_kw: 24.6,
          daily_yield_kwh: 142.8,
          peak_power_kwp: 30.0,
          inverter_efficiency_pct: 98.4,
          panel_temperature_c: 34.2,
          irradiance_w_m2: 845,
          inverter_status: 'sebeke_bagli',
          grid_voltage_v: 382,
          total_energy_mwh: 18.4,
        },
        iot: {
          air_temperature_c: 25.1,
          battery_pct: 96,
          last_seen_at: '2026-10-24T03:32:00Z',
        },
      },
      timestamps: {
        created_at: '2026-03-12T11:00:00Z',
        updated_at: '2026-10-24T03:32:00Z',
      },
    },
  },
  {
    asset_id: 'asset_trafo_001',
    name: 'Ana Dağıtım Trafosu & AG Panosu',
    type: 'Point',
    geometry: {
      type: 'Point',
      coordinates: [26.57195, 41.62098],
    },
    style: {
      color: '#f59e0b',
      icon: 'trafo',
    },
    properties: {
      iot_connected: true,
      local_x_m: 68.2,
      local_y_m: -7.5,
      local_origin: 'parcel_first_vertex',
      digital_card: {
        genel: {
          asset_code: 'SF-TRAFO-001',
          notes: '160 kVA 34.5/0.4 kV direk tipi trafo, parafudr korumalı, kompanzasyon ve dağıtım panosu.',
        },
        electric_infra: {
          transformer_capacity_kva: 160,
          primary_voltage_kv: 34.5,
          secondary_voltage_v: 380,
          active_load_kw: 42.4,
          power_factor: 0.97,
          oil_temperature_c: 46.5,
          cable_spec: '3x35+16 mm² XLPE Yeraltı Zırhlı',
          status: 'aktif',
        },
        iot: {
          air_temperature_c: 26.0,
          battery_pct: 100,
          last_seen_at: '2026-10-24T03:34:00Z',
        },
      },
      timestamps: {
        created_at: '2026-01-15T10:00:00Z',
        updated_at: '2026-10-24T03:34:00Z',
      },
    },
  },
  {
    asset_id: 'asset_kablo_001',
    name: 'Yeraltı Enerji Kablosu (Trafo ➔ GES ➔ Kuyu)',
    type: 'LineString',
    geometry: {
      type: 'LineString',
      coordinates: [
        [26.57195, 41.62098],
        [26.57188, 41.62092],
        [26.57135, 41.62072],
      ],
    },
    style: {
      color: '#eab308',
      icon: 'elektrik_kablo',
    },
    properties: {
      iot_connected: true,
      local_x_m: 45.0,
      local_y_m: -22.0,
      local_origin: 'parcel_first_vertex',
      digital_card: {
        genel: {
          asset_code: 'SF-KABLO-001',
          notes: 'Yeraltı kablo kanalı içerisinden çekilmiş zırhlı ana enerji besleme hattı (68.4 m).',
        },
        electric_infra: {
          transformer_capacity_kva: 160,
          primary_voltage_kv: 34.5,
          secondary_voltage_v: 380,
          active_load_kw: 28.6,
          power_factor: 0.96,
          oil_temperature_c: 32.0,
          cable_spec: '3x35+16 mm² NYY / XLPE Yeraltı Zırhlı',
          line_length_m: 68.4,
          status: 'aktif',
        },
      },
      timestamps: {
        created_at: '2026-01-16T12:00:00Z',
        updated_at: '2026-10-24T03:34:00Z',
      },
    },
  },
  {
    asset_id: 'asset_boru_001',
    name: 'Ana Sulama Boru Hattı (Kuyu ➔ Damla Hatları)',
    type: 'LineString',
    geometry: {
      type: 'LineString',
      coordinates: [
        [26.57135, 41.62072],
        [26.57145, 41.62085],
        [26.57165, 41.62085],
        [26.57175, 41.62075],
      ],
    },
    style: {
      color: '#0284c7',
      icon: 'su_borusu',
    },
    properties: {
      iot_connected: true,
      local_x_m: 35.0,
      local_y_m: -20.0,
      local_origin: 'parcel_first_vertex',
      digital_card: {
        genel: {
          asset_code: 'SF-BORU-001',
          notes: 'Ø90 mm PN10 yüksek yoğunluklu polietilen (HDPE 100) ana basınç hattı ve zon vanaları.',
        },
        water_infra: {
          pipe_spec: 'Ø90 mm PN10 HDPE 100',
          nominal_diameter_mm: 90,
          line_pressure_bar: 3.8,
          flow_velocity_m_s: 1.45,
          valve_status: 'acik',
          filter_dp_bar: 0.25,
          line_length_m: 54.2,
          target_zone: 'Zone 1 & 2 Ceviz Parselleri',
        },
      },
      timestamps: {
        created_at: '2026-02-18T10:00:00Z',
        updated_at: '2026-10-24T03:30:00Z',
      },
    },
  },
  {
    asset_id: 'asset_shed_001',
    name: 'Tarım Ekipman Deposu',
    type: 'Point',
    geometry: {
      type: 'Point',
      coordinates: [26.5712, 41.6209],
    },
    style: {
      color: '#b45309',
      icon: 'yapi',
    },
    properties: {
      iot_connected: false,
      local_x_m: 7.8,
      local_y_m: -15.4,
      local_origin: 'parcel_first_vertex',
      digital_card: {
        genel: {
          asset_code: 'SF-YAPI-001',
          notes: 'Prefabrik ekipman ve gübre depolama hangarı (60 m²).',
        },
      },
      timestamps: {
        created_at: '2026-01-20T08:00:00Z',
        updated_at: '2026-10-24T03:00:00Z',
      },
    },
  },
];

export const INITIAL_WORK_ORDERS: WorkOrder[] = [
  {
    work_order_id: 'WO-2026-0101',
    asset_id: 'asset_sensor_001',
    asset_name: 'IoT Toprak Nem & Hava Sensörü (Zone 1)',
    title: 'Toprak Nem Eşik Kontrolü ve Sensör Kalibrasyonu',
    description: 'Nem eşiği %22 seviyesine yaklaştı. Saha sensör problarını temizleyip kalibrasyon yapın.',
    assignee: 'Ahmet Yılmaz (Saha Teknisyeni)',
    priority: 'yuksek',
    status: 'devam_ediyor',
    created_at: '2026-10-23T11:00:00Z',
    due_at: '2026-10-25T17:00:00Z',
  },
  {
    work_order_id: 'WO-2026-0102',
    asset_id: 'asset_well_001',
    asset_name: 'Derin Kuyu & Pompa İstasyonu',
    title: 'Damla Sulama Filtre Temizliği',
    description: 'Haftalık disk ve kum filtre geri yıkama temizliği.',
    assignee: 'Mehmet Demir',
    priority: 'normal',
    status: 'bekliyor',
    created_at: '2026-10-24T01:30:00Z',
    due_at: '2026-10-26T12:00:00Z',
  },
  {
    work_order_id: 'WO-2026-0098',
    asset_id: 'asset_tree_001',
    asset_name: 'Ağaç No #14 (Ceviz)',
    title: 'Mevsimsel Yaprak Analizi Numunesi',
    description: 'Laboratuvar besin elementi analizi için yaprak numunesi toplandı.',
    assignee: 'Ayşe Kaya (Ziraat Müh.)',
    priority: 'dusuk',
    status: 'tamamlandi',
    created_at: '2026-10-18T09:00:00Z',
    completed_at: '2026-10-20T16:00:00Z',
    note: 'Numuneler Trakya Araştırma Enstitüsü laboratuvarına teslim edildi.',
  },
];
