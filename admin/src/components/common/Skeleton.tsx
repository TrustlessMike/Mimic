import { memo } from 'react';

interface SkeletonProps {
  className?: string;
}

export const Skeleton = memo(function Skeleton({ className = '' }: SkeletonProps) {
  return (
    <div className={`animate-pulse bg-dark-700/50 rounded ${className}`} />
  );
});

export const StatCardSkeleton = memo(function StatCardSkeleton() {
  return (
    <div className="stats-card">
      <div className="flex items-start justify-between">
        <div className="flex-1">
          <Skeleton className="h-4 w-24 mb-3" />
          <Skeleton className="h-8 w-16 mb-2" />
          <Skeleton className="h-4 w-20" />
        </div>
        <Skeleton className="w-12 h-12 rounded-xl" />
      </div>
    </div>
  );
});

export const TableRowSkeleton = memo(function TableRowSkeleton({ cols = 4 }: { cols?: number }) {
  return (
    <tr>
      {Array.from({ length: cols }).map((_, i) => (
        <td key={i} className="py-3">
          <Skeleton className="h-4 w-full max-w-[120px]" />
        </td>
      ))}
    </tr>
  );
});

export const ListItemSkeleton = memo(function ListItemSkeleton() {
  return (
    <div className="flex items-center justify-between p-3 rounded-xl bg-dark-800/50">
      <div className="flex items-center gap-3">
        <Skeleton className="w-10 h-10 rounded-lg" />
        <div>
          <Skeleton className="h-4 w-24 mb-2" />
          <Skeleton className="h-3 w-16" />
        </div>
      </div>
      <div className="text-right">
        <Skeleton className="h-4 w-16 mb-2 ml-auto" />
        <Skeleton className="h-5 w-12 ml-auto rounded-full" />
      </div>
    </div>
  );
});

export const CardSkeleton = memo(function CardSkeleton({ rows = 3 }: { rows?: number }) {
  return (
    <div className="glass-card p-6">
      <div className="flex items-center gap-3 mb-6">
        <Skeleton className="w-10 h-10 rounded-lg" />
        <Skeleton className="h-5 w-32" />
      </div>
      <div className="space-y-4">
        {Array.from({ length: rows }).map((_, i) => (
          <ListItemSkeleton key={i} />
        ))}
      </div>
    </div>
  );
});
