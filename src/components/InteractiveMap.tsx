import React, { useEffect, useRef, useState, useMemo } from 'react';
import L from 'leaflet';
import {
  ZoomIn,
  ZoomOut,
  Grid,
  Trash2,
  Edit3,
  Check,
  Trees,
  Home,
  Droplets,
  Radio,
  Sun,
  Ruler,
  ChevronDown,
  ChevronUp,
  X,
  Wrench,
  Layers,
  Zap,
  Activity,
  MapPin,
} from 'lucide-react';
import { LatLng, CanonicalAsset, ParcelFeature, AssetType, LayerVisibilityState } from '../types';
import {
  isPointInPolygon,
  snapToParcelOrGrid,
  haversineDistanceMeters,
  calculateLocalMeters,
  computePolygonClippedGrid,
  isAssetVisibleInLayers,
  calculatePolylineLengthMeters,
  getParcelDimensionMeters,
  buildParcelGridCellSizes,
  findParcelContainingPoint,
  MIN_GRID_CELL_METERS,
} from '../services/gisService';

function formatGridMeters(meters: number): string {
  const label = Number.isInteger(meters) ? String(meters) : meters.toFixed(1).replace(/\.0$/, '');
  return `${label}m`;
}

interface InteractiveMapProps {
  parcels: ParcelFeature[];
  selectedParcel: ParcelFeature | null;
  assets: CanonicalAsset[];
  selectedAsset: CanonicalAsset | null;
  selectedTool: AssetType | null;
  satelliteMode: boolean;
  editMode: boolean;
  movingAssetId: string | null;
  onToggleEditMode: () => void;
  onStartMoveAsset: (assetId: string) => void;
  onSelectParcel: (parcel: ParcelFeature) => void;
  onSelectAsset: (asset: CanonicalAsset) => void;
  onAddAsset: (type: AssetType, pos: LatLng, parcel: ParcelFeature) => void;
  onMoveAsset: (assetId: string, newPos: LatLng) => void;
  onDeleteAsset: (assetId: string) => void;
  onClearAllAssets: () => void;
  onSelectTool?: (tool: AssetType | null) => void;
  onCameraChange?: (center: LatLng, zoom: number) => void;
}

export const InteractiveMap: React.FC<InteractiveMapProps> = ({
  parcels,
  selectedParcel,
  assets,
  selectedAsset,
  selectedTool,
  satelliteMode,
  editMode,
  movingAssetId,
  onToggleEditMode,
  onStartMoveAsset,
  onSelectParcel,
  onSelectAsset,
  onAddAsset,
  onMoveAsset,
  onDeleteAsset,
  onClearAllAssets,
  onSelectTool,
  onCameraChange,
}) => {
  const mapContainerRef = useRef<HTMLDivElement>(null);
  const mapInstanceRef = useRef<L.Map | null>(null);
  const tileLayerRef = useRef<L.TileLayer | null>(null);
  const parcelLayerGroupRef = useRef<L.LayerGroup | null>(null);
  const assetLayerGroupRef = useRef<L.LayerGroup | null>(null);
  const gridLayerGroupRef = useRef<L.LayerGroup | null>(null);
  const measureLayerGroupRef = useRef<L.LayerGroup | null>(null);

  const [currentZoom, setCurrentZoom] = useState<number>(17);
  // User Requirement: Grid starts CLOSED by default ("Bununla ilgili ızgarayı kapalı açın")
  const [isGridVisible, setIsGridVisible] = useState<boolean>(false);
  const [isGridMenuOpen, setIsGridMenuOpen] = useState<boolean>(false);
  // User Requirement: Selectable grid resolution in meters (e.g. 2m, 3m, 5m, 10m)
  const [gridCellSize, setGridCellSize] = useState<number>(MIN_GRID_CELL_METERS);
  const [isToolMenuOpen, setIsToolMenuOpen] = useState<boolean>(false);
  const [isHoveringMenu, setIsHoveringMenu] = useState<boolean>(false);

  // Google Earth-style GIS Layers State
  const [isLayersMenuOpen, setIsLayersMenuOpen] = useState<boolean>(false);
  const [layers, setLayers] = useState<LayerVisibilityState>({
    trees: true,
    buildings: true,
    water: true,
    electric: true,
    sensors: true,
    cadastre: true,
    grid: false,
  });

  const toggleLayer = (layerKey: keyof LayerVisibilityState) => {
    setLayers((prev) => {
      const nextVal = !prev[layerKey];
      if (layerKey === 'grid') {
        setIsGridVisible(nextVal);
      }
      return { ...prev, [layerKey]: nextVal };
    });
  };

  const [mouseMeterPos, setMouseMeterPos] = useState<{ x: number; y: number } | null>(null);
  const [measurePoints, setMeasurePoints] = useState<LatLng[]>([]);
  const [, setLastDistanceMeters] = useState<number | null>(null);
  const [toastMessage, setToastMessage] = useState<string | null>(null);
  const [snapMessage, setSnapMessage] = useState<string | null>(null);

  const showToast = (msg: string) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 3500);
  };

  // Dimensions & Grid Counts for the selected parcel
  const parcelDimensions = useMemo(() => {
    if (!selectedParcel) {
      return { widthM: 0, heightM: 0, cellsX: 0, cellsY: 0, gridSizes: [MIN_GRID_CELL_METERS] };
    }
    const { widthMeters, heightMeters } = getParcelDimensionMeters(selectedParcel);
    const gridSizes = buildParcelGridCellSizes(widthMeters, heightMeters);
    return {
      widthM: widthMeters,
      heightM: heightMeters,
      cellsX: Math.max(1, Math.round(widthMeters / gridCellSize)),
      cellsY: Math.max(1, Math.round(heightMeters / gridCellSize)),
      gridSizes,
    };
  }, [selectedParcel, gridCellSize]);

  useEffect(() => {
    if (!selectedParcel) {
      return;
    }
    const { gridSizes } = parcelDimensions;
    if (!gridSizes.includes(gridCellSize)) {
      setGridCellSize(gridSizes[0] ?? MIN_GRID_CELL_METERS);
    }
  }, [selectedParcel, parcelDimensions, gridCellSize]);

  // 1. Initialize Leaflet Map
  useEffect(() => {
    if (!mapContainerRef.current || mapInstanceRef.current) return;

    const initialCenter: [number, number] = selectedParcel
      ? [selectedParcel.geometry.coordinates[0][0][1], selectedParcel.geometry.coordinates[0][0][0]]
      : [41.62103, 26.57218];

    const map = L.map(mapContainerRef.current, {
      center: initialCenter,
      zoom: 17,
      maxZoom: 22,
      zoomControl: false,
      attributionControl: false,
    });

    mapInstanceRef.current = map;

    // Layer Groups in Order
    parcelLayerGroupRef.current = L.layerGroup().addTo(map);
    gridLayerGroupRef.current = L.layerGroup().addTo(map);
    assetLayerGroupRef.current = L.layerGroup().addTo(map);
    measureLayerGroupRef.current = L.layerGroup().addTo(map);

    // Initial Tile Layer: maxNativeZoom: 18 ensures tiles scale seamlessly past zoom 18 without white screen
    const tileUrl = satelliteMode
      ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
      : 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';

    tileLayerRef.current = L.tileLayer(tileUrl, {
      maxZoom: 22,
      maxNativeZoom: 18,
      subdomains: satelliteMode ? [] : ['a', 'b', 'c'],
    }).addTo(map);

    const updateCameraState = () => {
      const center = map.getCenter();
      const zoom = map.getZoom();
      setCurrentZoom(zoom);
      onCameraChange?.({ lat: center.lat, lng: center.lng }, zoom);
    };

    map.on('moveend', updateCameraState);
    map.on('zoomend', updateCameraState);

    map.on('mousemove', (e: L.LeafletMouseEvent) => {
      if (selectedParcel) {
        const local = calculateLocalMeters({ lat: e.latlng.lat, lng: e.latlng.lng }, selectedParcel);
        setMouseMeterPos({
          x: parseFloat(local.local_x_m.toFixed(1)),
          y: parseFloat(local.local_y_m.toFixed(1)),
        });
      }
    });

    return () => {
      map.remove();
      mapInstanceRef.current = null;
    };
  }, []);

  // 2. Automatic ResizeObserver to handle sidebar collapse/expand without grey zones
  useEffect(() => {
    if (!mapContainerRef.current || !mapInstanceRef.current) return;
    const observer = new ResizeObserver(() => {
      mapInstanceRef.current?.invalidateSize();
    });
    observer.observe(mapContainerRef.current);
    return () => observer.disconnect();
  }, []);

  // 3. Tile layer update when switching satellite / vector
  useEffect(() => {
    if (!mapInstanceRef.current) return;
    if (tileLayerRef.current) {
      mapInstanceRef.current.removeLayer(tileLayerRef.current);
    }

    const tileUrl = satelliteMode
      ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
      : 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';

    tileLayerRef.current = L.tileLayer(tileUrl, {
      maxZoom: 22,
      maxNativeZoom: 18,
      subdomains: satelliteMode ? [] : ['a', 'b', 'c'],
    }).addTo(mapInstanceRef.current);
  }, [satelliteMode]);

  // 4. Render Polygon-Clipped Grid Layer (Inside Parcel Only, NO spillover outside)
  useEffect(() => {
    if (!mapInstanceRef.current || !gridLayerGroupRef.current) return;
    gridLayerGroupRef.current.clearLayers();

    if (!layers.grid || !isGridVisible || !selectedParcel) return;
    // Show grid when zoomed in enough for meter-level inspection
    if (currentZoom < 16.5) return;

    const { horizontalSegments, verticalSegments, origin } = computePolygonClippedGrid(
      selectedParcel,
      gridCellSize
    );

    // Draw horizontal lines (East-West)
    horizontalSegments.forEach((seg) => {
      const polyline = L.polyline([seg.p1, seg.p2], {
        color: seg.isMajor ? '#10b981' : '#059669',
        weight: seg.isMajor ? (currentZoom >= 19 ? 1.6 : 1.2) : 0.8,
        opacity: seg.isMajor ? (currentZoom >= 19 ? 0.8 : 0.6) : (currentZoom >= 19 ? 0.45 : 0.3),
        dashArray: seg.isMajor ? undefined : '3, 4',
        interactive: false,
      });
      gridLayerGroupRef.current?.addLayer(polyline);
    });

    // Draw vertical lines (North-South)
    verticalSegments.forEach((seg) => {
      const polyline = L.polyline([seg.p1, seg.p2], {
        color: seg.isMajor ? '#10b981' : '#059669',
        weight: seg.isMajor ? (currentZoom >= 19 ? 1.6 : 1.2) : 0.8,
        opacity: seg.isMajor ? (currentZoom >= 19 ? 0.8 : 0.6) : (currentZoom >= 19 ? 0.45 : 0.3),
        dashArray: seg.isMajor ? undefined : '3, 4',
        interactive: false,
      });
      gridLayerGroupRef.current?.addLayer(polyline);
    });

    // Origin Beacon Dot
    if (currentZoom >= 18.0 && origin.lat !== 0) {
      const originDot = L.circleMarker([origin.lat, origin.lng], {
        radius: 4.5,
        color: '#10b981',
        fillColor: '#ffffff',
        fillOpacity: 1,
        weight: 2,
        interactive: false,
      });
      gridLayerGroupRef.current.addLayer(originDot);
    }
  }, [selectedParcel, isGridVisible, currentZoom, gridCellSize, layers.grid]);

  // 5. Render Parcels
  useEffect(() => {
    if (!mapInstanceRef.current || !parcelLayerGroupRef.current) return;
    parcelLayerGroupRef.current.clearLayers();

    if (!layers.cadastre) return;

    const isCadMode = currentZoom >= 18.0;

    parcels.forEach((parcel) => {
      const isSelected = selectedParcel && selectedParcel.properties.ParselNo === parcel.properties.ParselNo;
      const geoCoordinates = parcel.geometry.coordinates;
      let latLngRings: L.LatLngExpression[][] = [];

      if (parcel.geometry.type === 'Polygon') {
        latLngRings = geoCoordinates.map((ring: [number, number][]) =>
          ring.map((coord) => [coord[1], coord[0]])
        );
      } else if (parcel.geometry.type === 'MultiPolygon') {
        latLngRings = geoCoordinates.map((poly: [number, number][][]) =>
          poly[0].map((coord) => [coord[1], coord[0]])
        );
      }

      const polygon = L.polygon(latLngRings, {
        color: isSelected ? (isCadMode ? '#34d399' : '#10b981') : '#38bdf8',
        weight: isSelected ? (isCadMode ? 3.5 : 3) : 2,
        dashArray: isSelected ? undefined : '5, 5',
        fillColor: isSelected ? (isCadMode ? '#064e3b' : '#10b981') : '#0284c7',
        fillOpacity: isSelected ? (isCadMode ? 0.32 : 0.22) : 0.12,
      });

      polygon.on('click', (e) => {
        // Harita tıklamasının parsele varlık eklemesini engelleme.
        if (!selectedTool && !movingAssetId && !editMode) {
          L.DomEvent.stopPropagation(e);
          onSelectParcel(parcel);
        }
      });

      const tooltipContent = `
        <div class="px-2.5 py-1.5 font-sans text-xs">
          <div class="font-bold text-emerald-400">${parcel.properties.name || `Parsel ${parcel.properties.ParselNo}`}</div>
          <div class="text-slate-300">Ada: ${parcel.properties.Ada || '-'} / Parsel: ${parcel.properties.ParselNo}</div>
          <div class="text-slate-400">Alan: ${parcel.properties.Alan} · ${parcel.properties.Nitelik}</div>
        </div>
      `;
      polygon.bindTooltip(tooltipContent, {
        sticky: true,
        className: 'bg-slate-900 border border-slate-700 text-slate-100 rounded-lg shadow-xl',
      });

      parcelLayerGroupRef.current?.addLayer(polygon);
    });
  }, [parcels, selectedParcel, currentZoom, layers.cadastre, selectedTool, movingAssetId, editMode]);

  // 6. Global Event Delegation to intercept marker delete clicks reliably
  useEffect(() => {
    const container = mapContainerRef.current;
    if (!container) return;

    const handleContainerClick = (e: MouseEvent) => {
      const target = e.target as HTMLElement | null;
      const deleteBtn = target?.closest('.asset-delete-btn') as HTMLElement | null;
      if (deleteBtn) {
        e.stopPropagation();
        e.preventDefault();
        const assetId = deleteBtn.getAttribute('data-asset-id');
        const rawName = deleteBtn.getAttribute('data-asset-name');
        const assetName = rawName ? decodeURIComponent(rawName) : 'Varlık';
        if (assetId) {
          if (window.confirm(`"${assetName}" varlığını silmek istediğinizden emin misiniz?`)) {
            onDeleteAsset(assetId);
            showToast(`"${assetName}" başarıyla silindi.`);
          }
        }
      }
    };

    container.addEventListener('click', handleContainerClick, true);
    return () => {
      container.removeEventListener('click', handleContainerClick, true);
    };
  }, [onDeleteAsset]);

  // 7. Render Digital Twin Assets & Live Telemetry Pins & Infrastructure Polylines
  useEffect(() => {
    if (!mapInstanceRef.current || !assetLayerGroupRef.current) return;
    assetLayerGroupRef.current.clearLayers();

    assets.forEach((asset) => {
      // 1. Check GIS Layer Visibility Filter
      if (!isAssetVisibleInLayers(asset, layers)) {
        return;
      }

      const isSelected = selectedAsset && selectedAsset.asset_id === asset.asset_id;
      const isMoving = movingAssetId === asset.asset_id;

      // 2. LINESTRING ASSETS (Infrastructure Polylines: Water Pipe or Electric Cable)
      if (asset.geometry.type === 'LineString' && Array.isArray(asset.geometry.coordinates)) {
        const lineCoords = (asset.geometry.coordinates as [number, number][]).map(
          (c) => [c[1], c[0]] as [number, number]
        );
        const isElectric = asset.style.icon === 'elektrik_kablo';
        const isWater = asset.style.icon === 'su_borusu';

        const polyline = L.polyline(lineCoords, {
          color: isElectric ? '#eab308' : isWater ? '#0284c7' : asset.style.color,
          weight: isSelected ? 5.5 : 4,
          dashArray: isElectric ? '8, 6' : undefined,
          opacity: isSelected ? 1.0 : 0.85,
        });

        polyline.on('click', (e) => {
          L.DomEvent.stopPropagation(e);
          if (editMode) {
            if (window.confirm(`"${asset.name}" altyapı hattını silmek istediğinizden emin misiniz?`)) {
              onDeleteAsset(asset.asset_id);
              showToast(`"${asset.name}" altyapı hattı silindi.`);
            }
          } else {
            onSelectAsset(asset);
          }
        });

        const card = asset.properties.digital_card;
        const lineLen =
          card?.electric_infra?.line_length_m ||
          card?.water_infra?.line_length_m ||
          calculatePolylineLengthMeters(asset.geometry.coordinates as [number, number][]);

        const tooltipContent = `
          <div class="px-2.5 py-1.5 font-sans text-xs">
            <div class="font-bold ${isElectric ? 'text-yellow-400' : 'text-sky-400'}">${asset.name}</div>
            <div class="text-slate-300 font-mono text-[11px]">
              ${isWater ? `Boru: ${card?.water_infra?.pipe_spec || 'Ø90 HDPE'} · ${card?.water_infra?.line_pressure_bar ?? 3.8} bar · Vana: ${card?.water_infra?.valve_status === 'acik' ? 'Açık' : 'Kapalı'}` : ''}
              ${isElectric ? `Kablo: ${card?.electric_infra?.cable_spec || '3x35+16 mm²'} · ${card?.electric_infra?.secondary_voltage_v ?? 380}V · Yük: ${card?.electric_infra?.active_load_kw ?? 28} kW` : ''}
            </div>
            <div class="text-emerald-400 font-mono text-[10px]">Hat Uzunluğu: ~${lineLen} m ${editMode ? '· (Silmek için tıkla)' : ''}</div>
          </div>
        `;
        polyline.bindTooltip(tooltipContent, {
          sticky: true,
          className: 'bg-slate-900 border border-slate-700 text-slate-100 rounded-lg shadow-xl',
        });

        assetLayerGroupRef.current?.addLayer(polyline);
        return;
      }

      // 3. POINT ASSETS
      const coords = asset.geometry.coordinates as [number, number];
      const lat = coords[1];
      const lng = coords[0];

      const card = asset.properties.digital_card;

      // Specialized Badge tailored to specific asset type
      let badgeHtml = '';
      if (asset.style.icon === 'gunes' && card?.solar) {
        badgeHtml = `
          <div style="
            position: absolute;
            top: -12px;
            right: -18px;
            background: #713f12;
            color: #fef08a;
            border: 1px solid #eab308;
            font-family: monospace;
            font-size: 9px;
            font-weight: bold;
            padding: 1px 4px;
            border-radius: 4px;
            white-space: nowrap;
            box-shadow: 0 2px 5px rgba(0,0,0,0.4);
          ">
            ${card.solar.current_power_kw} kW
          </div>
        `;
      } else if (asset.style.icon === 'kuyu' && card?.well_pump) {
        badgeHtml = `
          <div style="
            position: absolute;
            top: -12px;
            right: -18px;
            background: #0c4a6e;
            color: #7dd3fc;
            border: 1px solid #0284c7;
            font-family: monospace;
            font-size: 9px;
            font-weight: bold;
            padding: 1px 4px;
            border-radius: 4px;
            white-space: nowrap;
            box-shadow: 0 2px 5px rgba(0,0,0,0.4);
          ">
            ${card.well_pump.line_pressure_bar} bar
          </div>
        `;
      } else if (asset.style.icon === 'trafo' && card?.electric_infra) {
        badgeHtml = `
          <div style="
            position: absolute;
            top: -12px;
            right: -18px;
            background: #78350f;
            color: #fde68a;
            border: 1px solid #f59e0b;
            font-family: monospace;
            font-size: 9px;
            font-weight: bold;
            padding: 1px 4px;
            border-radius: 4px;
            white-space: nowrap;
            box-shadow: 0 2px 5px rgba(0,0,0,0.4);
          ">
            ${card.electric_infra.active_load_kw} kW
          </div>
        `;
      } else if (asset.style.icon === 'sensor' && card?.iot?.soil_moisture_pct !== undefined) {
        const moisture = card.iot.soil_moisture_pct;
        const isLowMoisture = typeof moisture === 'number' && moisture < 20.0;
        badgeHtml = `
          <div style="
            position: absolute;
            top: -12px;
            right: -16px;
            background: ${isLowMoisture ? '#7f1d1d' : '#064e3b'};
            color: ${isLowMoisture ? '#fca5a5' : '#6ee7b7'};
            border: 1px solid ${isLowMoisture ? '#ef4444' : '#10b981'};
            font-family: monospace;
            font-size: 9px;
            font-weight: bold;
            padding: 1px 4px;
            border-radius: 4px;
            white-space: nowrap;
            box-shadow: 0 2px 5px rgba(0,0,0,0.4);
          ">
            %${moisture}
          </div>
        `;
      } else if (asset.style.icon === 'agac' && card?.agac?.ndvi_score !== undefined) {
        badgeHtml = `
          <div style="
            position: absolute;
            top: -12px;
            right: -16px;
            background: #064e3b;
            color: #a7f3d0;
            border: 1px solid #10b981;
            font-family: monospace;
            font-size: 9px;
            font-weight: bold;
            padding: 1px 4px;
            border-radius: 4px;
            white-space: nowrap;
            box-shadow: 0 2px 5px rgba(0,0,0,0.4);
          ">
            NDVI ${card.agac.ndvi_score}
          </div>
        `;
      }

      // In editMode, render red delete badge right on top of the asset marker
      const markerHtml = `
        <div style="position: relative; display: flex; align-items: center; justify-content: center;">
          <div style="
            width: ${editMode ? '40px' : '34px'};
            height: ${editMode ? '40px' : '34px'};
            border-radius: 50%;
            background: #0f172a;
            border: 2px solid ${isMoving ? '#facc15' : asset.style.color};
            display: flex;
            align-items: center;
            justify-content: center;
            box-shadow: ${isMoving ? '0 0 20px #facc15' : isSelected ? '0 0 15px rgba(16, 185, 129, 0.8)' : '0 4px 12px rgba(0,0,0,0.6)'};
            cursor: pointer;
            transition: all 0.2s ease;
          ">
            ${getAssetIconSvg(asset.style.icon, isMoving ? '#facc15' : asset.style.color)}
          </div>

          ${badgeHtml}

          ${
            editMode
              ? `<button
                  type="button"
                  class="asset-delete-btn"
                  data-asset-id="${asset.asset_id}"
                  data-asset-name="${encodeURIComponent(asset.name)}"
                  title="${asset.name} Varlığını Sil"
                  style="
                    position: absolute;
                    top: -10px;
                    right: -10px;
                    width: 24px;
                    height: 24px;
                    background: #dc2626;
                    border: 2px solid #ffffff;
                    border-radius: 50%;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    color: white;
                    font-size: 11px;
                    cursor: pointer;
                    box-shadow: 0 2px 8px rgba(0,0,0,0.6);
                    z-index: 100;
                    pointer-events: auto;
                  "
                >
                  🗑️
                </button>
                <div style="
                  position: absolute;
                  bottom: -18px;
                  background: #1e293b;
                  color: #94a3b8;
                  font-size: 8px;
                  padding: 1px 4px;
                  border-radius: 3px;
                  white-space: nowrap;
                ">
                  Taşı / Sil
                </div>`
              : ''
          }
        </div>
      `;

      const customIcon = L.divIcon({
        className: 'custom-asset-marker',
        html: markerHtml,
        iconSize: [40, 40],
        iconAnchor: [20, 20],
      });

      const marker = L.marker([lat, lng], {
        icon: customIcon,
        draggable: editMode,
        title: asset.name,
      });

      marker.on('click', (e) => {
        L.DomEvent.stopPropagation(e);

        const originalEvt = e.originalEvent;
        const target = originalEvt?.target as HTMLElement | null;
        if (target?.closest('.asset-delete-btn')) {
          if (window.confirm(`"${asset.name}" varlığını silmek istediğinizden emin misiniz?`)) {
            onDeleteAsset(asset.asset_id);
            showToast(`"${asset.name}" silindi.`);
          }
          return;
        }

        if (editMode) {
          onStartMoveAsset(asset.asset_id);
          showToast(`"${asset.name}" taşınmak üzere seçildi. Yeni konuma tıklayın.`);
        } else {
          onSelectAsset(asset);
        }
      });

      marker.on('dragend', (e) => {
        const newLatLng = e.target.getLatLng();
        onMoveAsset(asset.asset_id, { lat: newLatLng.lat, lng: newLatLng.lng });
        showToast(`${asset.name} konumu güncellendi.`);
      });

      // Tailored tooltip content per asset type
      let specificDetails = '';
      if (card?.solar) {
        specificDetails = `<div class="text-yellow-400 font-mono text-[11px]">Güç: ${card.solar.current_power_kw} kW · Günlük: ${card.solar.daily_yield_kwh} kWh · Verim: %${card.solar.inverter_efficiency_pct}</div>`;
      } else if (card?.well_pump) {
        specificDetails = `<div class="text-sky-300 font-mono text-[11px]">Derinlik: ${card.well_pump.well_depth_m}m · Debi: ${card.well_pump.flow_rate_m3_h} m³/saat · Basınç: ${card.well_pump.line_pressure_bar} bar</div>`;
      } else if (card?.electric_infra) {
        specificDetails = `<div class="text-amber-300 font-mono text-[11px]">Kapasite: ${card.electric_infra.transformer_capacity_kva} kVA · Yük: ${card.electric_infra.active_load_kw} kW · Cos φ: ${card.electric_infra.power_factor}</div>`;
      } else if (card?.iot?.soil_moisture_pct !== undefined) {
        specificDetails = `<div class="text-sky-300 font-mono text-[11px]">Canlı Toprak Nemi: %${card.iot.soil_moisture_pct} · Sıcaklık: ${card.iot.air_temperature_c ?? '-'}°C</div>`;
      } else if (card?.agac) {
        specificDetails = `<div class="text-emerald-300 font-mono text-[11px]">${card.agac.species || 'Ceviz'} · ${card.agac.variety || 'Chandler'} · Yaş: ${card.agac.age_years || '4'}</div>`;
      }

      const tooltipContent = `
        <div class="px-2.5 py-1.5 font-sans text-xs">
          <div class="font-bold text-white">${asset.name}</div>
          <div class="text-slate-300">Kod: ${card?.genel?.asset_code || asset.asset_id}</div>
          ${specificDetails}
          ${asset.properties.local_x_m !== undefined ? `<div class="text-slate-400 font-mono text-[10px] mt-0.5">Yerel: X=${asset.properties.local_x_m}m, Y=${asset.properties.local_y_m}m</div>` : ''}
        </div>
      `;
      marker.bindTooltip(tooltipContent, {
        direction: 'top',
        className: 'bg-slate-900 border border-slate-700 text-slate-100 rounded-lg shadow-xl',
      });

      assetLayerGroupRef.current?.addLayer(marker);
    });
  }, [assets, selectedAsset, editMode, movingAssetId, layers]);

  // 8. Click on Map: Asset Placement, Snapping, Measurement
  useEffect(() => {
    const map = mapInstanceRef.current;
    if (!map) return;

    const handleMapClick = (e: L.LeafletMouseEvent) => {
      const clickPos: LatLng = { lat: e.latlng.lat, lng: e.latlng.lng };
      const hostParcel = findParcelContainingPoint(clickPos, parcels, selectedParcel);
      const snapThreshold = Math.max(gridCellSize, MIN_GRID_CELL_METERS);

      // Moving existing asset
      if (movingAssetId) {
        if (!selectedParcel) {
          showToast('İşlem için lütfen bir parsel seçin.');
          return;
        }
        const isInside = isPointInPolygon(clickPos, selectedParcel);
        if (!isInside) {
          showToast('Hata: Varlık parsel sınırları dışına taşınamaz!');
          return;
        }
        const { snappedPoint, snappedTo } = snapToParcelOrGrid(
          clickPos,
          selectedParcel,
          snapThreshold,
          gridCellSize
        );
        onMoveAsset(movingAssetId, snappedPoint);
        showToast(
          snappedTo !== 'none'
            ? `Varlık ${snappedTo === 'vertex' ? 'köşe noktasına' : `${formatGridMeters(gridCellSize)} ızgaraya`} kenetlenerek taşındı.`
            : 'Varlık yeni konuma yerleştirildi.'
        );
        return;
      }

      // Measurement
      if (selectedTool === 'olcum') {
        const newPoints = [...measurePoints, clickPos];
        setMeasurePoints(newPoints);

        if (newPoints.length >= 2) {
          const p1 = newPoints[newPoints.length - 2];
          const p2 = newPoints[newPoints.length - 1];
          const dist = haversineDistanceMeters(p1, p2);
          setLastDistanceMeters(parseFloat(dist.toFixed(2)));
          setSnapMessage(`Ölçüm: ${dist.toFixed(1)} m`);
        }
        return;
      }

      // Adding new asset — tıklanan parselin geometrisine bağlanır
      if (selectedTool) {
        if (!hostParcel) {
          showToast(
            selectedParcel
              ? 'Uyarı: Varlıklar yalnızca parsel sınırları içine eklenebilir!'
              : 'İşlem için lütfen bir parsel seçin.'
          );
          return;
        }

        const { snappedPoint, snappedTo, distanceMeters } = snapToParcelOrGrid(
          clickPos,
          hostParcel,
          snapThreshold,
          gridCellSize
        );
        const isInside = isPointInPolygon(snappedPoint, hostParcel);
        if (!isInside) {
          showToast('Uyarı: Varlıklar yalnızca parsel sınırları içine eklenebilir!');
          return;
        }

        onAddAsset(selectedTool, snappedPoint, hostParcel);
        if (snappedTo !== 'none') {
          setSnapMessage(
            `📍 ${snappedTo === 'vertex' ? 'Köşeye' : `${formatGridMeters(gridCellSize)} ızgaraya`} kenetlendi (${distanceMeters.toFixed(1)}m)`
          );
          setTimeout(() => setSnapMessage(null), 3500);
        }
        return;
      }

      if (hostParcel && !editMode) {
        onSelectParcel(hostParcel);
      }
    };

    map.on('click', handleMapClick);
    return () => {
      map.off('click', handleMapClick);
    };
  }, [selectedTool, selectedParcel, parcels, measurePoints, assets, movingAssetId, gridCellSize, editMode]);

  // 9. Measurement Polyline
  useEffect(() => {
    if (!measureLayerGroupRef.current) return;
    measureLayerGroupRef.current.clearLayers();

    if (measurePoints.length >= 2) {
      const latLngs = measurePoints.map((pt) => [pt.lat, pt.lng] as [number, number]);
      const polyline = L.polyline(latLngs, {
        color: '#06b6d4',
        weight: 3,
        dashArray: '5, 5',
      });
      measureLayerGroupRef.current.addLayer(polyline);

      measurePoints.forEach((pt) => {
        const circle = L.circleMarker([pt.lat, pt.lng], {
          radius: 5,
          color: '#06b6d4',
          fillColor: '#ffffff',
          fillOpacity: 1,
        });
        measureLayerGroupRef.current?.addLayer(circle);
      });
    }
  }, [measurePoints]);

  // 10. Focus camera on selected parcel
  useEffect(() => {
    if (!mapInstanceRef.current || !selectedParcel) return;
    try {
      const coords = selectedParcel.geometry.coordinates;
      let latLngs: [number, number][] = [];
      if (selectedParcel.geometry.type === 'Polygon' && coords[0]) {
        latLngs = coords[0].map((c: [number, number]) => [c[1], c[0]]);
      } else if (selectedParcel.geometry.type === 'MultiPolygon' && coords[0]?.[0]) {
        latLngs = coords[0][0].map((c: [number, number]) => [c[1], c[0]]);
      }
      if (latLngs.length > 0) {
        const bounds = L.latLngBounds(latLngs);
        mapInstanceRef.current.fitBounds(bounds, { padding: [80, 80], maxZoom: 19 });
      }
    } catch (e) {
      console.warn('fitBounds error:', e);
    }
  }, [selectedParcel]);

  const handleZoomIn = () => {
    mapInstanceRef.current?.zoomIn();
  };

  const handleZoomOut = () => {
    mapInstanceRef.current?.zoomOut();
  };

  // Tools list for Top-Right Overlay Hamburger / Popover Menu
  const metaTools: { id: AssetType; label: string; desc: string; icon: React.ReactNode; color: string; bgActive: string }[] = [
    {
      id: 'agac',
      label: 'Ağaç (Meyve / Zeytin / Ceviz)',
      desc: 'Parsel içi hassas fidan/ağaç konumu',
      icon: <Trees className="w-4 h-4 text-emerald-400" />,
      color: 'text-emerald-400',
      bgActive: 'bg-emerald-950/80 border-emerald-500 text-emerald-200',
    },
    {
      id: 'yapi',
      label: 'Yapı / Tesis / Çiftlik Deposu',
      desc: 'Hangar, soğuk hava deposu, bina',
      icon: <Home className="w-4 h-4 text-amber-400" />,
      color: 'text-amber-400',
      bgActive: 'bg-amber-950/80 border-amber-500 text-amber-200',
    },
    {
      id: 'kuyu',
      label: 'Su Kuyusu / Pompa İstasyonu',
      desc: '140m derin sondaj ve dalgıç pompa',
      icon: <Droplets className="w-4 h-4 text-sky-400" />,
      color: 'text-sky-400',
      bgActive: 'bg-sky-950/80 border-sky-500 text-sky-200',
    },
    {
      id: 'su_borusu',
      label: 'Su Borusu / Sulama Hattı',
      desc: 'Ø90 mm PN10 HDPE ana dağıtım hattı',
      icon: <Droplets className="w-4 h-4 text-cyan-400" />,
      color: 'text-cyan-400',
      bgActive: 'bg-cyan-950/80 border-cyan-500 text-cyan-200',
    },
    {
      id: 'trafo',
      label: 'Ana Trafo & Dağıtım Panosu',
      desc: '160 kVA 34.5/0.4 kV enerji merkezi',
      icon: <Activity className="w-4 h-4 text-amber-400" />,
      color: 'text-amber-400',
      bgActive: 'bg-amber-950/80 border-amber-500 text-amber-200',
    },
    {
      id: 'elektrik_kablo',
      label: 'Elektrik Kablosu / Enerji Hattı',
      desc: '3x35+16 mm² Yeraltı zırhlı iletim hattı',
      icon: <Zap className="w-4 h-4 text-yellow-400" />,
      color: 'text-yellow-400',
      bgActive: 'bg-yellow-950/80 border-yellow-500 text-yellow-200',
    },
    {
      id: 'gunes',
      label: 'Güneş Paneli (Solar GES)',
      desc: '30 kWp sulama enerjisi güneş paneli dizisi',
      icon: <Sun className="w-4 h-4 text-yellow-400" />,
      color: 'text-yellow-400',
      bgActive: 'bg-yellow-950/80 border-yellow-500 text-yellow-200',
    },
    {
      id: 'sensor',
      label: 'IoT Telemetri Sensör İstasyonu',
      desc: 'Toprak nemi (2 derinlik), pH, mikroklima',
      icon: <Radio className="w-4 h-4 text-orange-400" />,
      color: 'text-orange-400',
      bgActive: 'bg-orange-950/80 border-orange-500 text-orange-200',
    },
    {
      id: 'olcum',
      label: 'Ölçüm Cetveli (Mesafe / Boyut)',
      desc: 'İki nokta arası metrik uzunluk',
      icon: <Ruler className="w-4 h-4 text-cyan-400" />,
      color: 'text-cyan-400',
      bgActive: 'bg-cyan-950/80 border-cyan-500 text-cyan-200',
    },
  ];

  const activeToolObj = metaTools.find((t) => t.id === selectedTool);

  const activeLayersCount = Object.values(layers).filter(Boolean).length;
  const totalLayersCount = Object.keys(layers).length;

  const handleToggleAllLayers = () => {
    const allActive = activeLayersCount === totalLayersCount;
    const nextState: LayerVisibilityState = {
      trees: !allActive,
      buildings: !allActive,
      water: !allActive,
      electric: !allActive,
      sensors: !allActive,
      cadastre: !allActive,
      grid: !allActive,
    };
    setLayers(nextState);
    setIsGridVisible(!allActive);
  };

  return (
    <div className="relative w-full h-full overflow-hidden select-none bg-slate-950">
      {/* Map Element */}
      <div ref={mapContainerRef} className="w-full h-full z-0" />

      {/* Floating Snapping / Measurement Feedback */}
      {snapMessage && (
        <div className="absolute top-4 right-1/2 translate-x-1/2 z-20 px-3.5 py-1.5 rounded-full bg-slate-900/95 border border-amber-500/50 text-amber-300 font-bold text-xs shadow-xl animate-in fade-in duration-150">
          {snapMessage}
        </div>
      )}

      {/* Moving Prompt */}
      {movingAssetId && (
        <div className="absolute top-4 left-1/2 -translate-x-1/2 z-30 px-5 py-2.5 bg-blue-600 text-white font-bold text-xs rounded-full shadow-2xl flex items-center gap-2 animate-bounce">
          <span>📍 Varlık taşınıyor: Yeni konuma tıklayın...</span>
        </div>
      )}

      {/* Top Left: Zoom & Collapsible Translucent Grid Control */}
      <div className="absolute top-4 left-4 z-20 flex flex-col gap-2">
        {/* Zoom In / Out */}
        <div className="flex flex-col bg-slate-900/80 backdrop-blur-md border border-slate-700/80 rounded-xl overflow-hidden shadow-2xl w-fit">
          <button
            onClick={handleZoomIn}
            className="p-2.5 text-slate-200 hover:text-white hover:bg-slate-800 transition-colors cursor-pointer border-b border-slate-800"
            title="Yakınlaştır (+)"
          >
            <ZoomIn className="w-4 h-4 text-emerald-400" />
          </button>
          <button
            onClick={handleZoomOut}
            className="p-2.5 text-slate-200 hover:text-white hover:bg-slate-800 transition-colors cursor-pointer"
            title="Uzaklaştır (-)"
          >
            <ZoomOut className="w-4 h-4 text-slate-300" />
          </button>
        </div>

        {/* Collapsible Translucent Grid Control (Açılır Kapanır, Yer Kaplamaz) */}
        <div className="relative">
          <button
            onClick={() => setIsGridMenuOpen(!isGridMenuOpen)}
            className={`flex items-center gap-2 px-3 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer border backdrop-blur-xl shadow-2xl ${
              isGridVisible
                ? 'bg-emerald-950/80 hover:bg-emerald-900/80 text-emerald-300 border-emerald-500/70 shadow-emerald-950/50'
                : 'bg-slate-900/80 hover:bg-slate-800 text-slate-200 border-slate-700/80'
            }`}
            title="Izgara Ayarları (Açılır Kapanır)"
          >
            <Grid className="w-4 h-4 text-emerald-400" />
            <span>{isGridVisible ? `Izgara: ${formatGridMeters(gridCellSize)}` : 'Izgara: Kapalı'}</span>
            <ChevronDown className={`w-3.5 h-3.5 transition-transform duration-200 ${isGridMenuOpen ? 'rotate-180' : ''}`} />
          </button>

          {/* Grid Popover Card (Translucent / Backdrop-Blur) */}
          {isGridMenuOpen && (
            <div className="absolute left-0 top-full mt-2 w-64 bg-slate-900/90 backdrop-blur-2xl border border-slate-700/80 rounded-2xl shadow-2xl p-3 flex flex-col gap-2.5 z-30 animate-in fade-in slide-in-from-top-2 duration-150">
              {/* Toggle On/Off */}
              <button
                onClick={() => {
                  const next = !isGridVisible;
                  setIsGridVisible(next);
                  setLayers((prev) => ({ ...prev, grid: next }));
                }}
                className={`flex items-center justify-between w-full px-2.5 py-1.5 rounded-lg text-xs font-bold transition-all cursor-pointer border ${
                  isGridVisible
                    ? 'bg-emerald-950/90 border-emerald-500/70 text-emerald-300 shadow-sm'
                    : 'bg-slate-800/80 border-slate-700 text-slate-300 hover:text-white hover:bg-slate-700'
                }`}
              >
                <div className="flex items-center gap-1.5">
                  <Grid className="w-3.5 h-3.5 text-emerald-400" />
                  <span>{isGridVisible ? `Izgara Açık (${formatGridMeters(gridCellSize)})` : 'Izgara Kapalı'}</span>
                </div>
                <span
                  className={`w-2.5 h-2.5 rounded-full ${isGridVisible ? 'bg-emerald-400 animate-pulse' : 'bg-slate-500'}`}
                />
              </button>

              {/* Grid Resolution Buttons */}
              <div className="flex flex-col gap-1 pt-1 border-t border-slate-800">
                <div className="flex items-center justify-between text-[10px] text-slate-400 font-mono px-0.5">
                  <span>Hücre Çözünürlüğü:</span>
                  <span className="text-emerald-400 font-bold">
                    {formatGridMeters(gridCellSize)} × {formatGridMeters(gridCellSize)}
                  </span>
                </div>
                <div className="grid grid-cols-4 gap-1">
                  {parcelDimensions.gridSizes.map((size) => (
                    <button
                      key={size}
                      onClick={() => {
                        setGridCellSize(size);
                        if (!isGridVisible) {
                          setIsGridVisible(true);
                          setLayers((prev) => ({ ...prev, grid: true }));
                        }
                      }}
                      className={`py-1 text-[11px] font-bold rounded transition-colors cursor-pointer border ${
                        gridCellSize === size && isGridVisible
                          ? 'bg-emerald-600 border-emerald-400 text-white shadow-md'
                          : 'bg-slate-800/90 border-slate-700 text-slate-300 hover:text-white hover:bg-slate-700'
                      }`}
                      title={`${formatGridMeters(size)} × ${formatGridMeters(size)} parsel içi ızgara`}
                    >
                      {formatGridMeters(size)}
                    </button>
                  ))}
                </div>

                {/* Parcel Boundary Information */}
                {selectedParcel && (
                  <div className="text-[10px] text-slate-400 font-mono px-0.5 pt-1.5 leading-tight border-t border-slate-800/60 mt-1">
                    <div className="text-slate-300 font-semibold truncate">
                      {selectedParcel.properties.name || `Parsel ${selectedParcel.properties.ParselNo}`}
                    </div>
                    <div className="text-sky-300">
                      Boyut: {parcelDimensions.widthM.toFixed(1)}m × {parcelDimensions.heightM.toFixed(1)}m
                    </div>
                    <div className="text-emerald-400/90">
                      Grid: ~{parcelDimensions.cellsX} × ~{parcelDimensions.cellsY} hücre
                    </div>
                    <div className="text-[9px] text-slate-400 italic mt-0.5">
                      * Sadece parsel içi sınırlandırılmıştır
                    </div>
                  </div>
                )}
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Top Right: Floating Overlay Menu ("Varlık Ekle / Düzenleme Modu") */}
      <div
        className="absolute top-4 right-4 z-20"
        onMouseEnter={() => setIsHoveringMenu(true)}
        onMouseLeave={() => setIsHoveringMenu(false)}
      >
        <div className="relative">
          {/* Main Menu Trigger Button */}
          <button
            onClick={() => {
              if (!selectedParcel) {
                showToast('Varlık eklemek için önce bir parsel seçin.');
                return;
              }
              setIsToolMenuOpen(!isToolMenuOpen);
            }}
            className={`flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-bold shadow-2xl transition-all cursor-pointer border backdrop-blur-xl ${
              !selectedParcel
                ? 'bg-slate-900/70 text-slate-500 border-slate-800 cursor-not-allowed'
                : editMode
                ? 'bg-amber-500 hover:bg-amber-400 text-slate-950 border-amber-300 shadow-amber-500/40'
                : selectedTool
                ? 'bg-emerald-600 hover:bg-emerald-500 text-white border-emerald-400 shadow-emerald-600/40 animate-pulse'
                : 'bg-slate-900/90 hover:bg-slate-800 text-slate-100 border-slate-700'
            }`}
            title={selectedParcel ? 'Varlık Ekle ve Harita Düzenleme Menüsü' : 'Önce parsel seçin'}
          >
            {editMode ? (
              <>
                <Edit3 className="w-4 h-4 text-slate-950 stroke-[2.5]" />
                <span>Düzenleme Modu Aktif</span>
              </>
            ) : selectedTool ? (
              <>
                <Wrench className="w-4 h-4 text-white" />
                <span>Ekle: {activeToolObj?.label.split(' ')[0]}</span>
              </>
            ) : (
              <>
                <Wrench className="w-4 h-4 text-emerald-400" />
                <span>Varlık Ekle / Düzenle</span>
              </>
            )}
            <ChevronDown className={`w-3.5 h-3.5 transition-transform duration-200 ${isToolMenuOpen || isHoveringMenu ? 'rotate-180' : ''}`} />
          </button>

          {/* Dropdown Menu (Opened on Click or Hover) */}
          {selectedParcel && (isToolMenuOpen || isHoveringMenu) && (
            <div className="absolute right-0 top-full mt-2 w-76 bg-slate-900/95 backdrop-blur-2xl border border-slate-700 rounded-2xl shadow-2xl p-2.5 flex flex-col gap-2 z-30 animate-in fade-in slide-in-from-top-2 duration-150">
              {/* Düzenleme Modu (Taşı / Sil) Toggle Button */}
              <button
                onClick={() => {
                  onToggleEditMode();
                  onSelectTool?.(null);
                }}
                className={`flex items-center justify-between w-full p-2.5 rounded-xl text-xs font-bold transition-all cursor-pointer border ${
                  editMode
                    ? 'bg-amber-500 text-slate-950 border-amber-300 shadow-lg'
                    : 'bg-slate-800 hover:bg-slate-750 text-slate-200 border-slate-700 hover:border-amber-500/50'
                }`}
              >
                <div className="flex items-center gap-2">
                  {editMode ? <Check className="w-4 h-4 stroke-[3]" /> : <Edit3 className="w-4 h-4 text-amber-400" />}
                  <div className="flex flex-col text-left">
                    <span>{editMode ? 'Düzenleme Modundan Çık' : 'Düzenleme Moduna Geç'}</span>
                    <span className="text-[10px] font-normal opacity-80">
                      {editMode ? 'Taşıma ve silme aktif' : 'Varlık taşı ve üzerindeki 🗑️ ile sil'}
                    </span>
                  </div>
                </div>
                <span
                  className={`w-2.5 h-2.5 rounded-full ${editMode ? 'bg-slate-950 animate-ping' : 'bg-slate-500'}`}
                />
              </button>

              <div className="h-px bg-slate-800 my-0.5" />

              {/* Meta Asset Selection Section */}
              <div className="text-[10px] font-bold text-slate-400 uppercase tracking-wider px-1">
                Eklenecek Metayı Seçin:
              </div>

              <div className="flex flex-col gap-1 max-h-72 overflow-y-auto pr-0.5">
                {metaTools.map((tool) => {
                  const isActive = selectedTool === tool.id;
                  return (
                    <button
                      key={tool.id}
                      onClick={() => {
                        if (editMode) onToggleEditMode();
                        onSelectTool?.(isActive ? null : tool.id);
                        if (!isActive) {
                          showToast(`"${tool.label}" ekleme modu aktif. Parsel içinde tıklayın.`);
                        }
                      }}
                      className={`flex items-center gap-2.5 p-2 rounded-xl text-left text-xs transition-all cursor-pointer border ${
                        isActive
                          ? `${tool.bgActive} border shadow-md font-bold`
                          : 'bg-slate-800/70 hover:bg-slate-800 text-slate-300 border-slate-700/60 hover:text-white'
                      }`}
                    >
                      <div className="p-1 rounded-lg bg-slate-900 border border-slate-700 flex-shrink-0">
                        {tool.icon}
                      </div>
                      <div className="flex flex-col min-w-0 flex-1">
                        <span className="truncate">{tool.label}</span>
                        <span className="text-[10px] text-slate-400 truncate">{tool.desc}</span>
                      </div>
                      {isActive && <Check className="w-4 h-4 text-emerald-400 ml-auto flex-shrink-0" />}
                    </button>
                  );
                })}
              </div>

              {/* Clear All Assets Option */}
              {assets.length > 0 && (
                <>
                  <div className="h-px bg-slate-800 my-0.5" />
                  <button
                    onClick={() => {
                      if (window.confirm('Tüm dijital ikiz varlıkları silmek istediğinizden emin misiniz?')) {
                        onClearAllAssets();
                        showToast('Tüm varlıklar temizlendi.');
                      }
                    }}
                    className="flex items-center justify-center gap-2 py-2 px-3 text-xs text-red-400 hover:text-red-300 hover:bg-red-950/40 border border-red-900/40 rounded-xl transition-colors cursor-pointer"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                    <span>Tüm Varlıkları Sil ({assets.length})</span>
                  </button>
                </>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Active Tool Feedback Strip below top-right menu */}
      {selectedTool && (
        <div className="absolute top-16 right-4 z-20 flex items-center gap-2.5 px-3.5 py-2 bg-emerald-950/95 border border-emerald-500/70 text-emerald-200 text-xs font-medium rounded-xl shadow-2xl backdrop-blur-md animate-in fade-in duration-200">
          <span>
            📍 <strong>{activeToolObj?.label}</strong> ekleme modu aktif ({formatGridMeters(gridCellSize)} snap). Parsel içine tıklayın.
          </span>
          <button
            onClick={() => onSelectTool?.(null)}
            className="p-1 hover:bg-emerald-800 rounded-lg text-emerald-300 hover:text-white cursor-pointer"
            title="Seçimi İptal Et"
          >
            <X className="w-3.5 h-3.5" />
          </button>
        </div>
      )}

      {/* Bottom Right: Google Earth Style GIS Katmanlar (Layers) Control */}
      <div className="absolute bottom-4 right-4 z-20 flex flex-col items-end gap-2">
        <div className="relative">
          <button
            onClick={() => setIsLayersMenuOpen(!isLayersMenuOpen)}
            className="flex items-center gap-2 px-3.5 py-2 rounded-xl bg-slate-900/90 hover:bg-slate-800 text-slate-100 border border-slate-700/80 text-xs font-bold shadow-2xl backdrop-blur-xl transition-all cursor-pointer"
            title="Google Earth Tarzı GIS Katman Yönetimi"
          >
            <Layers className="w-4 h-4 text-sky-400" />
            <span>Katmanlar</span>
            <span className="px-1.5 py-0.5 rounded-full bg-sky-950 border border-sky-800/80 text-[10px] text-sky-300 font-mono font-bold">
              {activeLayersCount}/{totalLayersCount}
            </span>
            <ChevronUp className={`w-3.5 h-3.5 transition-transform duration-200 ${isLayersMenuOpen ? 'rotate-180' : ''}`} />
          </button>

          {/* GIS Layers Checkboxes Popover */}
          {isLayersMenuOpen && (
            <div className="absolute right-0 bottom-full mb-2 w-76 bg-slate-900/95 backdrop-blur-2xl border border-slate-700 rounded-2xl shadow-2xl p-3 flex flex-col gap-2.5 z-30 animate-in fade-in slide-in-from-bottom-2 duration-150">
              <div className="flex items-center justify-between pb-1.5 border-b border-slate-800">
                <div className="flex items-center gap-1.5 text-xs font-bold text-white">
                  <Layers className="w-4 h-4 text-sky-400" />
                  <span>GIS Katmanları (Google Earth)</span>
                </div>
                <button
                  onClick={handleToggleAllLayers}
                  className="text-[10px] text-emerald-400 hover:text-emerald-300 font-semibold cursor-pointer"
                >
                  {activeLayersCount === totalLayersCount ? 'Tümünü Kapat' : 'Tümünü Aç'}
                </button>
              </div>

              {/* Layer Checkboxes */}
              <div className="flex flex-col gap-1 text-xs">
                {/* 1. Ağaçlar */}
                <label className="flex items-center justify-between p-2 rounded-xl bg-slate-800/70 hover:bg-slate-800 border border-slate-700/60 cursor-pointer transition-colors">
                  <div className="flex items-center gap-2">
                    <Trees className="w-4 h-4 text-emerald-400" />
                    <span className="text-slate-200 font-medium">Ağaçlar & Dikili Alanlar</span>
                  </div>
                  <input
                    type="checkbox"
                    checked={layers.trees}
                    onChange={() => toggleLayer('trees')}
                    className="w-4 h-4 rounded text-emerald-500 focus:ring-emerald-400 cursor-pointer accent-emerald-500"
                  />
                </label>

                {/* 2. Yapılar & Tesisler */}
                <label className="flex items-center justify-between p-2 rounded-xl bg-slate-800/70 hover:bg-slate-800 border border-slate-700/60 cursor-pointer transition-colors">
                  <div className="flex items-center gap-2">
                    <Home className="w-4 h-4 text-amber-400" />
                    <span className="text-slate-200 font-medium">Yapılar & Tesisler</span>
                  </div>
                  <input
                    type="checkbox"
                    checked={layers.buildings}
                    onChange={() => toggleLayer('buildings')}
                    className="w-4 h-4 rounded text-amber-500 focus:ring-amber-400 cursor-pointer accent-amber-500"
                  />
                </label>

                {/* 3. Su Altyapısı */}
                <label className="flex items-center justify-between p-2 rounded-xl bg-slate-800/70 hover:bg-slate-800 border border-slate-700/60 cursor-pointer transition-colors">
                  <div className="flex items-center gap-2">
                    <Droplets className="w-4 h-4 text-sky-400" />
                    <div className="flex flex-col">
                      <span className="text-slate-200 font-medium">Su Altyapısı</span>
                      <span className="text-[10px] text-slate-400">Derin kuyu ve boru hatları</span>
                    </div>
                  </div>
                  <input
                    type="checkbox"
                    checked={layers.water}
                    onChange={() => toggleLayer('water')}
                    className="w-4 h-4 rounded text-sky-500 focus:ring-sky-400 cursor-pointer accent-sky-500"
                  />
                </label>

                {/* 4. Elektrik Altyapısı */}
                <label className="flex items-center justify-between p-2 rounded-xl bg-slate-800/70 hover:bg-slate-800 border border-slate-700/60 cursor-pointer transition-colors">
                  <div className="flex items-center gap-2">
                    <Zap className="w-4 h-4 text-yellow-400" />
                    <div className="flex flex-col">
                      <span className="text-slate-200 font-medium">Elektrik Altyapısı</span>
                      <span className="text-[10px] text-slate-400">GES santrali, trafo, kablolar</span>
                    </div>
                  </div>
                  <input
                    type="checkbox"
                    checked={layers.electric}
                    onChange={() => toggleLayer('electric')}
                    className="w-4 h-4 rounded text-yellow-500 focus:ring-yellow-400 cursor-pointer accent-yellow-500"
                  />
                </label>

                {/* 5. IoT Telemetri Sensörleri */}
                <label className="flex items-center justify-between p-2 rounded-xl bg-slate-800/70 hover:bg-slate-800 border border-slate-700/60 cursor-pointer transition-colors">
                  <div className="flex items-center gap-2">
                    <Radio className="w-4 h-4 text-orange-400" />
                    <span className="text-slate-200 font-medium">IoT Telemetri Sensörleri</span>
                  </div>
                  <input
                    type="checkbox"
                    checked={layers.sensors}
                    onChange={() => toggleLayer('sensors')}
                    className="w-4 h-4 rounded text-orange-500 focus:ring-orange-400 cursor-pointer accent-orange-500"
                  />
                </label>

                {/* 6. Parsel Kadastro Sınırı */}
                <label className="flex items-center justify-between p-2 rounded-xl bg-slate-800/70 hover:bg-slate-800 border border-slate-700/60 cursor-pointer transition-colors">
                  <div className="flex items-center gap-2">
                    <MapPin className="w-4 h-4 text-teal-400" />
                    <span className="text-slate-200 font-medium">Parsel & Kadastro Sınırı</span>
                  </div>
                  <input
                    type="checkbox"
                    checked={layers.cadastre}
                    onChange={() => toggleLayer('cadastre')}
                    className="w-4 h-4 rounded text-teal-500 focus:ring-teal-400 cursor-pointer accent-teal-500"
                  />
                </label>

                {/* 7. Metrik Grid Izgarası */}
                <label className="flex items-center justify-between p-2 rounded-xl bg-slate-800/70 hover:bg-slate-800 border border-slate-700/60 cursor-pointer transition-colors">
                  <div className="flex items-center gap-2">
                    <Grid className="w-4 h-4 text-emerald-400" />
                    <span className="text-slate-200 font-medium">Metrik Grid Izgarası</span>
                  </div>
                  <input
                    type="checkbox"
                    checked={layers.grid}
                    onChange={() => toggleLayer('grid')}
                    className="w-4 h-4 rounded text-emerald-500 focus:ring-emerald-400 cursor-pointer accent-emerald-500"
                  />
                </label>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Bottom Status HUD Bar */}
      <div className="absolute bottom-4 left-4 z-20 bg-slate-900/90 backdrop-blur-md border border-slate-800 text-[11px] font-mono text-slate-300 px-3.5 py-1.5 rounded-lg flex items-center gap-3 shadow-xl">
        <div className="flex items-center gap-1.5">
          <span
            className={`w-2 h-2 rounded-full ${currentZoom >= 17.5 ? 'bg-emerald-400 animate-pulse' : 'bg-slate-500'}`}
          />
          <span className="font-semibold text-emerald-400">
            {currentZoom >= 17.5 ? `${formatGridMeters(gridCellSize)} Grid CAD Modu` : 'Genel Görünüm'} (Z: {currentZoom.toFixed(1)})
          </span>
        </div>
        <span className="text-slate-600">·</span>
        <span>Snap: {formatGridMeters(gridCellSize)} Izgara / {formatGridMeters(Math.max(gridCellSize, MIN_GRID_CELL_METERS))} Köşe</span>
        {mouseMeterPos && (
          <>
            <span className="text-slate-600">·</span>
            <span className="text-sky-300 font-bold">
              X: {mouseMeterPos.x > 0 ? `+${mouseMeterPos.x}` : mouseMeterPos.x}m, Y:{' '}
              {mouseMeterPos.y > 0 ? `+${mouseMeterPos.y}` : mouseMeterPos.y}m
            </span>
          </>
        )}
      </div>

      {/* Toast Notification */}
      {toastMessage && (
        <div className="absolute top-4 left-1/2 -translate-x-1/2 z-30 bg-slate-900/95 border border-slate-700 text-slate-100 text-xs px-4 py-2.5 rounded-xl shadow-2xl flex items-center gap-2 animate-in fade-in slide-in-from-top-2 duration-200">
          <span className="w-2 h-2 rounded-full bg-emerald-400"></span>
          <span>{toastMessage}</span>
        </div>
      )}
    </div>
  );
};

// SVG Icon Helper
function getAssetIconSvg(type: AssetType, color: string): string {
  switch (type) {
    case 'agac':
      return `
        <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="${color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M12 22v-7"/>
          <path d="M17 14l-5-5-5 5h10z"/>
          <path d="M15 9l-3-3-3 3h6z"/>
        </svg>
      `;
    case 'kuyu':
      return `
        <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="${color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M12 2v20"/>
          <path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/>
        </svg>
      `;
    case 'su_borusu':
      return `
        <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="${color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="12" cy="12" r="3"/>
          <path d="M3 12h6"/>
          <path d="M15 12h6"/>
          <path d="M12 3v6"/>
          <path d="M12 15v6"/>
        </svg>
      `;
    case 'yapi':
      return `
        <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="${color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
          <polyline points="9 22 9 12 15 12 15 22"/>
        </svg>
      `;
    case 'sensor':
      return `
        <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="${color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M4.9 19.1C1 15.2 1 8.8 4.9 4.9"/>
          <path d="M7.8 16.2c-2.3-2.3-2.3-6.1 0-8.5"/>
          <circle cx="12" cy="12" r="2"/>
          <path d="M16.2 7.8c2.3 2.3 2.3 6.1 0 8.5"/>
          <path d="M19.1 4.9C23 8.8 23 15.1 19.1 19.1"/>
        </svg>
      `;
    case 'gunes':
      return `
        <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="${color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="12" cy="12" r="4"/>
          <path d="M12 2v2"/>
          <path d="M12 20v2"/>
          <path d="m4.93 4.93 1.41 1.41"/>
          <path d="m17.66 17.66 1.41 1.41"/>
          <path d="M2 12h2"/>
          <path d="M20 12h2"/>
          <path d="m6.34 17.66-1.41 1.41"/>
          <path d="m19.07 4.93-1.41 1.41"/>
        </svg>
      `;
    case 'trafo':
      return `
        <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="${color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <rect x="4" y="4" width="16" height="16" rx="2"/>
          <path d="M8 12h8"/>
          <path d="M12 8v8"/>
        </svg>
      `;
    case 'elektrik_kablo':
      return `
        <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="${color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/>
        </svg>
      `;
    default:
      return `
        <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="${color}" stroke-width="2">
          <circle cx="12" cy="12" r="8"/>
        </svg>
      `;
  }
}
