import { OperationalSignalDoc } from "../lib/types";

interface SignalBadgesProps {
  signals: OperationalSignalDoc[];
}

const SIGNAL_CONFIG: Record<
  string,
  { label: string; className: string }
> = {
  "24hs": {
    label: "24 horas",
    className: "bg-blue-50 text-blue-700",
  },
  late_night: {
    label: "Hasta tarde",
    className: "bg-purple-50 text-purple-700",
  },
  special_hours: {
    label: "Horario especial",
    className: "bg-amber-50 text-amber-700",
  },
  special_service: {
    label: "Servicio especial",
    className: "bg-teal-50 text-teal-700",
  },
  night_delivery: {
    label: "Delivery nocturno",
    className: "bg-indigo-50 text-indigo-700",
  },
};

export default function SignalBadges({ signals }: SignalBadgesProps) {
  const activeSignals = signals.filter((s) => s.status === "active");

  if (activeSignals.length === 0) return null;

  return (
    <div className="flex flex-wrap gap-2">
      {activeSignals.map((signal) => {
        const config = SIGNAL_CONFIG[signal.signalType];
        if (!config) return null;

        return (
          <span
            key={signal.id}
            className={`inline-flex items-center rounded-full px-3 py-1 text-xs font-medium ${config.className}`}
          >
            {config.label}
            {signal.notes && (
              <span className="ml-1 opacity-70">· {signal.notes}</span>
            )}
          </span>
        );
      })}
    </div>
  );
}
