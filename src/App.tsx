import React, { useState, useEffect, useRef } from 'react';
import { TopBar, ActiveTab } from './components/TopBar';
import { InteractiveMap } from './components/InteractiveMap';
import { AssetDetailModal } from './components/AssetDetailModal';
import { WorkOrdersPanel } from './components/WorkOrdersPanel';
import { IoTTelemetryPanel } from './components/IoTTelemetryPanel';
import { AdminPanel } from './components/AdminPanel';
import { TestRunnerPanel } from './components/TestRunnerPanel';
import { SolPanel } from './components/SolPanel';
import { SagPanel } from './components/SagPanel';
import { ParcelFeature, CanonicalAsset, AssetType, WorkOrder, WorkOrderStatus, IoTTelemetry, FarmKpi, AuditLogEntry, LatLng } from './types';
import { EDIRNE_PARCEL, MILAS_PARCEL, INITIAL_ASSETS, INITIAL_WORK_ORDERS } from './services/sampleData';
import { createNewAsset, calculateLocalMeters } from './services/gisService';

export const App: React.FC = () => {
  // Navigation & Panels State
  const [activeTab, setActiveTab] = useState<ActiveTab>('map');
  const [isSolPanelOpen, setIsSolPanelOpen] = useState<boolean>(true);
  const [isSagPanelOpen, setIsSagPanelOpen] = useState<boolean>(false);
  const [editMode, setEditMode] = useState<boolean>(false);
  const [movingAssetId, setMovingAssetId] = useState<string | null>(null);

  // Data State
  const [parcels, setParcels] = useState<ParcelFeature[]>([EDIRNE_PARCEL, MILAS_PARCEL]);
  const [selectedParcel, setSelectedParcel] = useState<ParcelFeature | null>(EDIRNE_PARCEL);
  const [assets, setAssets] = useState<CanonicalAsset[]>(INITIAL_ASSETS);
  const [selectedAsset, setSelectedAsset] = useState<CanonicalAsset | null>(null);
  const [selectedTool, setSelectedTool] = useState<AssetType | null>(null);
  const [satelliteMode, setSatelliteMode] = useState<boolean>(true);
  const [workOrders, setWorkOrders] = useState<WorkOrder[]>(INITIAL_WORK_ORDERS);
  const [telemetryLogs, setTelemetryLogs] = useState<IoTTelemetry[]>([
    {
      schema_version: 'ws.live.telemetry.v1',
      asset_id: 'asset_sensor_001',
      device_id: 'SF-IOT-001',
      metrics: {
        soil_moisture_pct: 22.4,
        air_temperature_c: 24.8,
        air_humidity_pct: 51,
        soil_ph: 6.85,
        battery_pct: 91,
      },
      alerts: ['Toprak Nemi Eşik Uyarısı (%22.4 < %25)'],
      measured_at: new Date().toLocaleTimeString('tr-TR'),
      quality_flag: 'good_quality',
    },
  ]);
  const [activeAlerts, setActiveAlerts] = useState<
    { id: string; asset_id: string; title: string; severity: 'warning' | 'critical'; created_at: string; message?: string }[]
  >([
    {
      id: 'ALT-904',
      asset_id: 'asset_sensor_001',
      title: 'Kritik Nem Düşüklüğü: %22.4',
      message: 'Zone 1 Toprak nemi kritik seviyenin altında (%22.4 < %25). Damla sulama başlatılması önerilir.',
      severity: 'warning',
      created_at: new Date().toISOString(),
    },
  ]);
  const [auditLogs, setAuditLogs] = useState<AuditLogEntry[]>([
    { at: new Date().toISOString(), event: 'smartfarm_xr_session_initialized', user: 'system' },
    { at: new Date().toISOString(), event: 'parcels_loaded_edirne_milas', user: 'system' },
  ]);

  const fileInputRef = useRef<HTMLInputElement>(null);

  // Load from LocalStorage
  useEffect(() => {
    try {
      const saved = localStorage.getItem('smartfarm_state_v2');
      if (saved) {
        const parsed = JSON.parse(saved);
        if (parsed.assets) setAssets(parsed.assets);
        if (parsed.workOrders) setWorkOrders(parsed.workOrders);
        if (parsed.parcels) setParcels(parsed.parcels);
      }
    } catch (e) {
      console.warn('LocalStorage error:', e);
    }
  }, []);

  // Save to LocalStorage
  useEffect(() => {
    try {
      localStorage.setItem(
        'smartfarm_state_v2',
        JSON.stringify({
          assets,
          workOrders,
          parcels,
        })
      );
    } catch (e) {
      console.warn('LocalStorage save error:', e);
    }
  }, [assets, workOrders, parcels]);

  // Handlers
  const handleAddAsset = (type: AssetType, pos: LatLng) => {
    if (!selectedParcel) return;
    const newAsset = createNewAsset(type, pos, selectedParcel);
    setAssets((prev) => [...prev, newAsset]);

    setAuditLogs((prev) => [
      {
        at: new Date().toISOString(),
        event: `asset_added_${type}_${newAsset.asset_id}`,
        user: 'operator',
      },
      ...prev,
    ]);
  };

  const handleMoveAsset = (assetId: string, newPos: LatLng) => {
    setAssets((prev) =>
      prev.map((a) => {
        if (a.asset_id !== assetId) return a;
        const local = selectedParcel ? calculateLocalMeters(newPos, selectedParcel) : { local_x_m: 0, local_y_m: 0 };
        
        // TypeScript Hatası Çözümü: Sadece 'Point' geometrileri tek bir LatLng ile güncellenebilir.
        if (a.geometry.type === 'Point') {
          return {
            ...a,
            geometry: {
              ...a.geometry,
              type: 'Point',
              coordinates: [newPos.lng, newPos.lat] as [number, number],
            },
            properties: {
              ...a.properties,
              local_x_m: local.local_x_m,
              local_y_m: local.local_y_m,
              timestamps: {
                ...a.properties.timestamps,
                updated_at: new Date().toISOString(),
                last_operation: 'asset_moved',
              },
            },
          } as CanonicalAsset; // Tip güvenliğini garanti altına alıyoruz
        }

        // Eğer obje Point değilse (LineString veya Polygon ise) koordinatlarını bozmamak için aynı bırakıyoruz.
        return a;
      })
    );
    setMovingAssetId(null);
  };

  const handleUpdateAsset = (updated: CanonicalAsset) => {
    setAssets((prev) => prev.map((a) => (a.asset_id === updated.asset_id ? updated : a)));
    setSelectedAsset(null);
  };

  const handleDeleteAsset = (assetId: string) => {
    setAssets((prev) => prev.filter((a) => a.asset_id !== assetId));
    if (selectedAsset?.asset_id === assetId) {
      setSelectedAsset(null);
    }
    setAuditLogs((prev) => [
      {
        at: new Date().toISOString(),
        event: `asset_deleted_${assetId}`,
        user: 'operator',
      },
      ...prev,
    ]);
  };

  const handleClearAllAssets = () => {
    setAssets([]);
  };

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (event) => {
      try {
        const content = event.target?.result as string;
        const json = JSON.parse(content);

        let newParcelFeatures: ParcelFeature[] = [];
        if (json.type === 'FeatureCollection' && Array.isArray(json.features)) {
          newParcelFeatures = json.features.filter(
            (f: any) => f.geometry && (f.geometry.type === 'Polygon' || f.geometry.type === 'MultiPolygon')
          );
        } else if (json.type === 'Feature' && json.geometry) {
          newParcelFeatures = [json as ParcelFeature];
        } else if (json.features && Array.isArray(json.features)) {
          newParcelFeatures = json.features;
        }

        if (newParcelFeatures.length > 0) {
          const first = newParcelFeatures[0];
          setParcels((prev) => [...newParcelFeatures, ...prev]);
          setSelectedParcel(first);
          setActiveTab('map');
          alert(`${newParcelFeatures.length} adet parsel başarıyla yüklendi!`);
        } else {
          alert('Dosyada geçerli parsel geometrisi bulunamadı.');
        }
      } catch (err) {
        alert('Dosya parse edilemedi.');
      }
    };
    reader.readAsText(file);
    e.target.value = '';
  };

  // Saha Aktar (Field Ingest)
  const handleFieldIngest = () => {
    if (!selectedParcel) return;
    const centerLng = selectedParcel.geometry.coordinates[0][0][0] + 0.0003;
    const centerLat = selectedParcel.geometry.coordinates[0][0][1] - 0.0002;
    const gpsAsset = createNewAsset('sensor', { lat: centerLat, lng: centerLng }, selectedParcel);
    gpsAsset.name = 'Saha GPS İnceleme Noktası (Mobil İstemci)';
    gpsAsset.properties.digital_card = {
      genel: {
        asset_code: `SF-FIELD-${Math.floor(100 + Math.random() * 900)}`,
        notes: 'SmartFarm Field Android uygulaması üzerinden toplanan saha GPS doğrulaması.',
      },
      iot: {
        soil_moisture_pct: 28.5,
        air_temperature_c: 24.1,
        battery_pct: 88,
        signal_dbm: -64,
        last_seen_at: new Date().toISOString(),
      },
    };
    setAssets((prev) => [...prev, gpsAsset]);
    alert('Saha dijitalleştirme ingest akışı tamamlandı: Yeni saha verisi eklendi.');
  };

  // IoT Demo Pulse (Emit Telemetry & Trigger Alerts)
  const handleTriggerDemoTelemetry = () => {
    const sensorAsset = assets.find((a) => a.style.icon === 'sensor') || assets[0];
    const newMoisture = parseFloat((15.0 + Math.random() * 8.0).toFixed(1));
    const newTemp = parseFloat((22.0 + Math.random() * 6.0).toFixed(1));
    const isAlert = newMoisture < 20.0;

    // Update the asset's digital card in place so the map marker badge reflects it immediately!
    setAssets((prev) =>
      prev.map((a) => {
        if (a.asset_id !== sensorAsset.asset_id) return a;
        return {
          ...a,
          properties: {
            ...a.properties,
            digital_card: {
              ...a.properties.digital_card,
              iot: {
                ...a.properties.digital_card?.iot,
                soil_moisture_pct: newMoisture,
                air_temperature_c: newTemp,
                last_seen_at: new Date().toISOString(),
              },
            },
          },
        };
      })
    );

    const newLog: IoTTelemetry = {
      schema_version: 'ws.live.telemetry.v1',
      asset_id: sensorAsset.asset_id,
      device_id: 'SF-IOT-001',
      metrics: {
        soil_moisture_pct: newMoisture,
        air_temperature_c: newTemp,
        air_humidity_pct: Math.floor(45 + Math.random() * 20),
        battery_pct: 90,
      },
      alerts: isAlert ? [`Toprak Nemi Kritik Seviyede (%${newMoisture} < %20)`] : [],
      measured_at: new Date().toLocaleTimeString('tr-TR'),
      quality_flag: 'good_quality',
    };

    setTelemetryLogs((prev) => [newLog, ...prev.slice(0, 19)]);

    if (isAlert) {
      const newAlert = {
        id: `ALT-${Math.floor(100 + Math.random() * 900)}`,
        asset_id: sensorAsset.asset_id,
        title: `Kritik Eşik Aşımı: Toprak Nemi %${newMoisture}`,
        message: `${sensorAsset.name} sensöründe nem seviyesi acil sulama eşiğinin altına indi.`,
        severity: 'critical' as const,
        created_at: new Date().toISOString(),
      };
      setActiveAlerts((prev) => [newAlert, ...prev]);
      setIsSagPanelOpen(true);
    }
  };

  // ERP Sync
  const handleErpSync = () => {
    alert('ERP senkronizasyon kuyruğa alındı (connector: generic).');
  };

  // Work Order Creation
  const handleAddWorkOrder = (orderData: Omit<WorkOrder, 'work_order_id' | 'created_at'>) => {
    const newOrder: WorkOrder = {
      ...orderData,
      work_order_id: `WO-2026-${Math.floor(1000 + Math.random() * 9000)}`,
      created_at: new Date().toISOString(),
    };
    setWorkOrders((prev) => [newOrder, ...prev]);
  };

  const handleUpdateWorkOrderStatus = (id: string, status: WorkOrderStatus) => {
    setWorkOrders((prev) =>
      prev.map((wo) =>
        wo.work_order_id === id
          ? {
              ...wo,
              status,
              completed_at: status === 'tamamlandi' ? new Date().toISOString() : undefined,
            }
          : wo
      )
    );
  };

  const handleAcknowledgeAlert = (alertId: string) => {
    alert(`Alarm ${alertId} operatör tarafından onaylandı.`);
  };

  const handleCloseAlert = (alertId: string) => {
    setActiveAlerts((prev) => prev.filter((a) => a.id !== alertId));
  };

  // KPI Calculations
  const kpi: FarmKpi = {
    assets_total: assets.length,
    work_orders_open: workOrders.filter((w) => w.status !== 'tamamlandi' && w.status !== 'iptal').length,
    alerts_count: activeAlerts.length,
    trees_count: assets.filter((a) => a.style.icon === 'agac').length,
    wells_count: assets.filter((a) => a.style.icon === 'kuyu').length,
    sensors_count: assets.filter((a) => a.style.icon === 'sensor').length,
    solar_count: assets.filter((a) => a.style.icon === 'gunes').length,
  };

  return (
    <div className="flex flex-col w-screen h-screen overflow-hidden bg-slate-950 text-slate-100 font-sans select-none">
      {/* Hidden File Input */}
      <input
        ref={fileInputRef}
        type="file"
        accept=".geojson,.json,.kml"
        onChange={handleFileUpload}
        className="hidden"
      />

      {/* Floating Top Bar (Matching Flutter Dashboard Top Row & Action Buttons) */}
      <TopBar
        activeTab={activeTab}
        onTabChange={setActiveTab}
        selectedParcel={selectedParcel}
        parcels={parcels}
        onSelectParcel={setSelectedParcel}
        satelliteMode={satelliteMode}
        onToggleSatellite={() => setSatelliteMode(!satelliteMode)}
        onUploadParcelClick={() => fileInputRef.current?.click()}
        onFieldIngestClick={handleFieldIngest}
        onWorkOrderQuickClick={() => {
          const first = assets[0];
          handleAddWorkOrder({
            asset_id: first?.asset_id || 'SF-GENEL',
            asset_name: first?.name || 'Genel Parsel',
            title: 'Saha Rutin Bakım Kontrolü',
            description: 'Operatör tarafından hızlı iş emri talebi oluşturuldu.',
            assignee: 'Ahmet Yılmaz (Saha Teknisyeni)',
            priority: 'normal',
            status: 'bekliyor',
          });
          setActiveTab('work_orders');
        }}
        onIoTDemoClick={handleTriggerDemoTelemetry}
        onErpSyncClick={handleErpSync}
        onOverviewResetClick={() => {
          const next = parcels.find((p) => p.properties.ParselNo !== selectedParcel?.properties.ParselNo) || parcels[0];
          setSelectedParcel(next);
        }}
        isSolPanelOpen={isSolPanelOpen}
        onToggleSolPanel={() => setIsSolPanelOpen(!isSolPanelOpen)}
        isSagPanelOpen={isSagPanelOpen}
        onToggleSagPanel={() => setIsSagPanelOpen(!isSagPanelOpen)}
        kpi={kpi}
      />

      {/* Main Viewport */}
      <main className="relative flex-1 w-full h-[calc(100vh-53px)] overflow-hidden">
        {activeTab === 'map' && (
          <div className="flex-1 flex flex-row w-full h-full overflow-hidden bg-slate-950">
            {/* Left Docked Sidebar (SolPanel: Dijital İkiz & IoT Telemetri) */}
            {isSolPanelOpen && (
              <aside className="w-80 md:w-88 flex-shrink-0 h-full border-r border-slate-800 bg-slate-900/95 z-20 flex flex-col shadow-2xl overflow-hidden transition-all duration-200">
                <SolPanel
                  onClose={() => setIsSolPanelOpen(false)}
                  assets={assets}
                  onSelectAsset={(a) => setSelectedAsset(a)}
                  onAddWorkOrderFromAsset={(a) => {
                    handleAddWorkOrder({
                      asset_id: a.asset_id,
                      asset_name: a.name,
                      title: `${a.name} Bakım Emri`,
                      description: 'Sol panel üzerinden oluşturuldu.',
                      assignee: 'Ahmet Yılmaz',
                      priority: 'normal',
                      status: 'bekliyor',
                    });
                    setActiveTab('work_orders');
                  }}
                />
              </aside>
            )}

            {/* Center Map Viewport */}
            <section className="relative flex-1 h-full min-w-0 overflow-hidden flex flex-col">
              <InteractiveMap
                parcels={parcels}
                selectedParcel={selectedParcel}
                assets={assets}
                selectedAsset={selectedAsset}
                selectedTool={selectedTool}
                satelliteMode={satelliteMode}
                editMode={editMode}
                movingAssetId={movingAssetId}
                onToggleEditMode={() => setEditMode(!editMode)}
                onStartMoveAsset={(id) => setMovingAssetId(id)}
                onSelectParcel={(p) => setSelectedParcel(p)}
                onSelectAsset={(a) => setSelectedAsset(a)}
                onAddAsset={handleAddAsset}
                onMoveAsset={handleMoveAsset}
                onDeleteAsset={handleDeleteAsset}
                onClearAllAssets={handleClearAllAssets}
                onSelectTool={(tool) => setSelectedTool(selectedTool === tool ? null : tool)}
              />
            </section>

            {/* Right Docked Sidebar (SagPanel: Alarmlar & Uyarılar) */}
            {isSagPanelOpen && (
              <aside className="w-80 md:w-88 flex-shrink-0 h-full border-l border-slate-800 bg-slate-900/95 z-20 flex flex-col shadow-2xl overflow-hidden transition-all duration-200">
                <SagPanel
                  onClose={() => setIsSagPanelOpen(false)}
                  alerts={activeAlerts}
                  onAcknowledge={handleAcknowledgeAlert}
                  onCloseAlert={handleCloseAlert}
                  onCreateWorkOrderFromAlert={(alert) => {
                    handleAddWorkOrder({
                      asset_id: alert.asset_id,
                      title: `Alarm Müdahale: ${alert.title}`,
                      description: alert.message || 'Alarm paneli üzerinden oluşturulan acil iş emri.',
                      assignee: 'Ahmet Yılmaz',
                      priority: alert.severity === 'critical' ? 'acil' : 'yuksek',
                      status: 'bekliyor',
                    });
                    setActiveTab('work_orders');
                  }}
                />
              </aside>
            )}
          </div>
        )}

        {activeTab === 'work_orders' && (
          <div className="w-full h-full overflow-hidden">
            <WorkOrdersPanel
              workOrders={workOrders}
              assets={assets}
              onAddWorkOrder={handleAddWorkOrder}
              onUpdateStatus={handleUpdateWorkOrderStatus}
              onBackToMap={() => setActiveTab('map')}
            />
          </div>
        )}

        {activeTab === 'telemetry' && (
          <div className="w-full h-full overflow-hidden">
            <IoTTelemetryPanel
              assets={assets}
              onTriggerDemoTelemetry={handleTriggerDemoTelemetry}
              telemetryLogs={telemetryLogs}
              activeAlerts={activeAlerts}
              onAcknowledgeAlert={handleAcknowledgeAlert}
              onCloseAlert={handleCloseAlert}
              onBackToMap={() => setActiveTab('map')}
            />
          </div>
        )}

        {activeTab === 'admin' && (
          <div className="w-full h-full overflow-hidden">
            <AdminPanel
              parcels={parcels}
              auditLogs={auditLogs}
              onBackToMap={() => setActiveTab('map')}
            />
          </div>
        )}

        {activeTab === 'tests' && (
          <div className="w-full h-full overflow-hidden">
            <TestRunnerPanel onBackToMap={() => setActiveTab('map')} />
          </div>
        )}
      </main>

      {/* Asset Inspection Modal */}
      {selectedAsset && (
        <AssetDetailModal
          asset={selectedAsset}
          onClose={() => setSelectedAsset(null)}
          onSave={handleUpdateAsset}
          onDelete={handleDeleteAsset}
          onCreateWorkOrder={(a) => {
            handleAddWorkOrder({
              asset_id: a.asset_id,
              asset_name: a.name,
              title: `${a.name} Bakım ve Kontrol Talebi`,
              description: 'Varlık detay kartı üzerinden açılan bakım iş emri.',
              assignee: 'Ahmet Yılmaz (Saha Teknisyeni)',
              priority: 'normal',
              status: 'bekliyor',
            });
            setActiveTab('work_orders');
          }}
        />
      )}
    </div>
  );
};

export default App;
