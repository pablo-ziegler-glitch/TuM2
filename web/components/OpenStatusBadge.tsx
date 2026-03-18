interface OpenStatusBadgeProps {
  isOpenNow: boolean;
  isOnDutyToday?: boolean;
  isLateNight?: boolean;
}

export default function OpenStatusBadge({
  isOpenNow,
  isOnDutyToday,
  isLateNight,
}: OpenStatusBadgeProps) {
  return (
    <div className="flex flex-wrap items-center gap-1.5">
      {/* Open/Closed status */}
      <span
        className={`inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-xs font-medium ${
          isOpenNow
            ? "bg-green-50 text-green-700"
            : "bg-red-50 text-red-700"
        }`}
      >
        <span
          className={`h-1.5 w-1.5 rounded-full ${
            isOpenNow ? "bg-green-500" : "bg-red-500"
          }`}
        />
        {isOpenNow ? "Abierto ahora" : "Cerrado"}
      </span>

      {/* Farmacia de turno */}
      {isOnDutyToday && (
        <span className="inline-flex items-center rounded-full bg-blue-50 px-2.5 py-0.5 text-xs font-medium text-blue-700">
          Farmacia de turno
        </span>
      )}

      {/* Late night */}
      {isLateNight && (
        <span className="inline-flex items-center rounded-full bg-purple-50 px-2.5 py-0.5 text-xs font-medium text-purple-700">
          Hasta tarde
        </span>
      )}
    </div>
  );
}
