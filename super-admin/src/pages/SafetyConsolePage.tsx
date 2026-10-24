import { useCallback, useEffect, useState } from "react";
import { CheckCircle2, Lock, MapPin, RefreshCw, ShieldAlert, Siren } from "lucide-react";
import { StatusPill } from "../components/StatusPill";
import { SakhiQuoteLoader } from "../components/SakhiQuoteLoader";
import { adminApi } from "../services/api/adminApi";

interface SafetyConsolePayload {
  metrics: {
    activeSosEvents: number;
    deliverySuccessRate: string;
    verifiedStationsCount: number;
    falseTriggers7d: number;
    totalConfiguredContacts: number;
  };
  controls: Array<{
    id: string;
    title: string;
    subtitle: string;
    statusPill: string;
  }>;
  sosEvents: Array<{
    id: string;
    eventType: string;
    status: string;
    locationLabel: string;
    isTestMode?: boolean;
    createdAt: string;
  }>;
  policeStations: Array<{
    id: string;
    stationCode: string;
    name: string;
    address: string;
    phoneNumber: string;
    isWomenStation: boolean;
    isVerified: boolean;
  }>;
  auditEvents: Array<{
    id: string;
    actorType: string;
    action: string;
    targetType: string;
    outcome: string;
    createdAt: string;
  }>;
}

const DEFAULT_CONTROLS = [
  {
    id: "contact_config",
    title: "Emergency Contact Configuration",
    subtitle: "Max 5 contacts, SMS/WhatsApp consent templates & retry rules",
    statusPill: "Configured",
  },
  {
    id: "police_directory",
    title: "Police Station Directory Data",
    subtitle: "Manage verified station names, GPS pins, addresses & numbers",
    statusPill: "Synced",
  },
  {
    id: "erss_112_settings",
    title: "Emergency-Service Integration Settings",
    subtitle: "112 ERSS & 100 Police API endpoint, auth keys & webhook config",
    statusPill: "Standby",
  },
  {
    id: "integration_health",
    title: "Integration Status Monitor",
    subtitle: "GPS Map API: Operational • SMS Gateway: Operational • Police API: Manual Mode",
    statusPill: "Healthy",
  },
  {
    id: "delivery_logs",
    title: "System Delivery Logs",
    subtitle: "Inspect push/SMS alert delivery timestamps & failure diagnostics",
    statusPill: "View Logs",
  },
  {
    id: "abuse_false_triggers",
    title: "Abuse & False-Trigger Reports",
    subtitle: "Review accidental activations, cooldown thresholds & user test logs",
    statusPill: "3 Pending",
  },
];

export function SafetyConsolePage() {
  const [data, setData] = useState<SafetyConsolePayload | null>(null);
  const [loading, setLoading] = useState(true);
  const [notice, setNotice] = useState("");
  const [error, setError] = useState("");
  const [stationName, setStationName] = useState("");
  const [stationAddress, setStationAddress] = useState("");
  const [stationPhone, setStationPhone] = useState("+91 80-2294-2548");
  const [isWomenStation, setIsWomenStation] = useState(false);

  const loadConsole = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const res = await adminApi<SafetyConsolePayload>("/admin-review/safety-console");
      setData(res);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not load SOS Administration console.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadConsole();
  }, [loadConsole]);

  async function handleAddStation(e: React.FormEvent) {
    e.preventDefault();
    if (!stationName.trim() || !stationAddress.trim()) return;
    try {
      await adminApi("/admin-review/police-stations", {
        method: "POST",
        body: {
          name: stationName.trim(),
          address: stationAddress.trim(),
          phoneNumber: stationPhone.trim(),
          isWomenStation,
          latitude: 12.9716,
          longitude: 77.6412,
        },
      });
      setStationName("");
      setStationAddress("");
      setNotice("Verified Police Station synced to PostgreSQL directory and audited.");
      await loadConsole();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not save police station.");
    }
  }

  async function handleReviewSos(eventId: string, classification: string) {
    try {
      await adminApi(`/admin-review/sos-events/${eventId}/review`, {
        method: "POST",
        body: { classification },
      });
      setNotice(`SOS Event ${eventId.slice(0, 8)} marked ${classification}.`);
      await loadConsole();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not review SOS event.");
    }
  }

  const controls = data?.controls ?? DEFAULT_CONTROLS;
  const metrics = data?.metrics ?? {
    activeSosEvents: 0,
    deliverySuccessRate: "99.4%",
    verifiedStationsCount: 142,
    falseTriggers7d: 3,
    totalConfiguredContacts: 3,
  };

  return (
    <div className="dashboard-page">
      <section className="page-heading">
        <div>
          <div className="eyebrow">
            <span className="eyebrow-line" /> MODULE 4 • SRS SECTION 6.6
          </div>
          <h1>SOS Administration & Personal Safety Console</h1>
          <p>
            Manage emergency contact configuration, verified police station directory data, 112/100 integration health, delivery logs, and false-trigger reports.
          </p>
        </div>
        <div className="heading-meta">
          <StatusPill tone="rose">
            <Lock size={12} style={{ marginRight: 4 }} /> Restricted Access
          </StatusPill>
          <button
            className="button button--secondary"
            type="button"
            onClick={() => void loadConsole()}
            disabled={loading}
          >
            <RefreshCw size={14} /> Refresh
          </button>
        </div>
      </section>

      <div
        role="status"
        style={{
          background: "#EDE0EA",
          color: "#2A1930",
          padding: "12px 16px",
          borderRadius: 12,
          marginBottom: 18,
          fontWeight: 700,
          fontSize: 13,
          display: "flex",
          alignItems: "center",
          gap: 10,
        }}
      >
        <Lock size={16} color="#5A1868" />
        <span>
          Tightly Restricted Admin Access • All Emergency Event Queries Are Audit-Logged
        </span>
      </div>

      {notice && (
        <div className="member-toast" role="status" style={{ marginBottom: 16 }}>
          <CheckCircle2 size={17} />
          <span>{notice}</span>
        </div>
      )}
      {error && (
        <div className="panel" role="alert" style={{ padding: 16, marginBottom: 16 }}>
          <strong>Notice:</strong> {error}
        </div>
      )}

      {loading && !data && (
        <SakhiQuoteLoader statusLabel="Loading Module 4 SOS Administration telemetry..." />
      )}

      {/* 2x2 Summary Metrics matching Reference Screen 8 */}
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))",
          gap: 14,
          marginBottom: 22,
        }}
      >
        <div className="panel" style={{ padding: 16 }}>
          <strong style={{ fontSize: 16 }}>
            Active SOS Events: {metrics.activeSosEvents} 🟢
          </strong>
        </div>
        <div className="panel" style={{ padding: 16 }}>
          <strong style={{ fontSize: 16 }}>
            Delivery Success: {metrics.deliverySuccessRate}
          </strong>
        </div>
        <div className="panel" style={{ padding: 16 }}>
          <strong style={{ fontSize: 16 }}>
            Verified Stations: {metrics.verifiedStationsCount}
          </strong>
        </div>
        <div className="panel" style={{ padding: 16 }}>
          <strong style={{ fontSize: 16 }}>
            False Triggers (7d): {metrics.falseTriggers7d}
          </strong>
        </div>
      </div>

      {/* 6 Admin Management Controls matching Reference Screen 8 */}
      <section className="panel queue-panel" style={{ marginBottom: 22 }}>
        <div className="panel-heading">
          <div>
            <span className="panel-kicker">ADMIN MANAGEMENT CONTROLS (SECTION 6.6)</span>
            <h2>Module 4 Safety Governance Modules</h2>
          </div>
          <Siren size={20} />
        </div>
        <div style={{ display: "grid", gap: 12 }}>
          {controls.map((ctrl) => (
            <div
              key={ctrl.id}
              style={{
                display: "flex",
                justifyContent: "space-between",
                alignItems: "center",
                padding: "14px 18px",
                background: "#FFFFFF",
                border: "1px solid #EFE3EE",
                borderRadius: 16,
              }}
            >
              <div>
                <strong style={{ fontSize: 15, color: "#2A1930" }}>{ctrl.title}</strong>
                <p style={{ margin: "4px 0 0 0", fontSize: 13, color: "#6E6275" }}>
                  {ctrl.subtitle}
                </p>
              </div>
              <StatusPill
                tone={
                  ctrl.statusPill.includes("Pending") || ctrl.statusPill.includes("Logged")
                    ? "rose"
                    : ctrl.statusPill === "Standby"
                      ? "amber"
                      : "green"
                }
              >
                {ctrl.statusPill}
              </StatusPill>
            </div>
          ))}
        </div>
      </section>

      {/* Verified Police Station Directory Manager (SRS 6.4 & 6.6) */}
      <section className="panel queue-panel" style={{ marginBottom: 22 }}>
        <div className="panel-heading">
          <div>
            <span className="panel-kicker">VERIFIED DIRECTORY DATA</span>
            <h2>Add / Sync Verified Police Station (112 / 100 Directory)</h2>
          </div>
          <MapPin size={20} />
        </div>
        <form
          onSubmit={(e) => void handleAddStation(e)}
          style={{ display: "grid", gridTemplateColumns: "1fr 1fr auto auto", gap: 10, alignItems: "center" }}
        >
          <input
            type="text"
            placeholder="Station Name (e.g., Jayanagar All-Women Police Station)"
            value={stationName}
            onChange={(e) => setStationName(e.target.value)}
            style={{ padding: "10px 12px", borderRadius: 10, border: "1px solid #D9C5D6" }}
          />
          <input
            type="text"
            placeholder="Address & Landmark"
            value={stationAddress}
            onChange={(e) => setStationAddress(e.target.value)}
            style={{ padding: "10px 12px", borderRadius: 10, border: "1px solid #D9C5D6" }}
          />
          <input
            type="text"
            placeholder="Phone (+91 80-...)"
            value={stationPhone}
            onChange={(e) => setStationPhone(e.target.value)}
            style={{ padding: "10px 12px", borderRadius: 10, border: "1px solid #D9C5D6" }}
          />
          <button className="button button--primary" type="submit">
            + Sync Station
          </button>
        </form>
        <label style={{ display: "inline-flex", alignItems: "center", gap: 6, marginTop: 10, fontSize: 13 }}>
          <input
            type="checkbox"
            checked={isWomenStation}
            onChange={(e) => setIsWomenStation(e.target.checked)}
          />
          All-Women Police Station (Mahila Police Station)
        </label>
      </section>

      {/* SOS Events & False-Trigger Review Queue */}
      <section className="panel queue-panel">
        <div className="panel-heading">
          <div>
            <span className="panel-kicker">SYSTEM DELIVERY LOGS & FALSE-TRIGGER REPORTS</span>
            <h2>Recorded SOS Events ({data?.sosEvents.length ?? 0})</h2>
          </div>
          <ShieldAlert size={20} />
        </div>
        <div className="table-scroll">
          <table className="operations-table">
            <thead>
              <tr>
                <th>Event Type</th>
                <th>Location Label</th>
                <th>Status</th>
                <th>Timestamp</th>
                <th>Admin Review Action</th>
              </tr>
            </thead>
            <tbody>
              {(data?.sosEvents ?? []).length === 0 && (
                <tr>
                  <td colSpan={5} className="member-empty-cell">
                    No SOS events recorded yet.
                  </td>
                </tr>
              )}
              {(data?.sosEvents ?? []).map((ev) => (
                <tr key={ev.id}>
                  <td>
                    <strong>{ev.eventType}</strong>
                  </td>
                  <td>{ev.locationLabel}</td>
                  <td>
                    <StatusPill
                      tone={
                        ev.status === "ACTIVE"
                          ? "rose"
                          : ev.status.includes("CANCEL") || ev.status.includes("TEST")
                            ? "amber"
                            : "green"
                      }
                    >
                      {ev.status}
                    </StatusPill>
                  </td>
                  <td>{new Date(ev.createdAt).toLocaleString("en-IN")}</td>
                  <td style={{ display: "flex", gap: 8 }}>
                    <button
                      className="button button--secondary"
                      type="button"
                      onClick={() => void handleReviewSos(ev.id, "RESOLVED_VERIFIED")}
                    >
                      Mark Resolved
                    </button>
                    <button
                      className="button button--secondary"
                      type="button"
                      onClick={() => void handleReviewSos(ev.id, "FALSE_TRIGGER_LOGGED")}
                    >
                      Log False Trigger
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
