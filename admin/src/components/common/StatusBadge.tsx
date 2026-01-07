interface StatusBadgeProps {
  status: string;
}

const statusColors: Record<string, string> = {
  success: 'bg-green-100 text-green-800',
  completed: 'bg-green-100 text-green-800',
  paid: 'bg-green-100 text-green-800',
  active: 'bg-green-100 text-green-800',
  pending: 'bg-yellow-100 text-yellow-800',
  failed: 'bg-red-100 text-red-800',
  rejected: 'bg-red-100 text-red-800',
  expired: 'bg-gray-100 text-gray-800',
  partial: 'bg-orange-100 text-orange-800',
};

export function StatusBadge({ status }: StatusBadgeProps) {
  const colorClass = statusColors[status.toLowerCase()] || 'bg-gray-100 text-gray-800';

  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${colorClass}`}>
      {status}
    </span>
  );
}
