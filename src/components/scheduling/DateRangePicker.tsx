// src/components/scheduling/DateRangePicker.tsx
"use client"

import * as React from "react"
import { DateRange } from "react-day-picker"
import { Calendar } from "@/components/ui/calendar"
import { Popover, PopoverTrigger, PopoverContent } from "@/components/ui/popover"
import { Button } from "@/components/ui/button"
import { Calendar as CalendarIcon, ChevronDown } from "lucide-react"
import { format, subDays, startOfWeek, endOfWeek } from "date-fns"
import { cn } from "@/lib/utils"

export function DateRangePicker({
  range,
  onChange,
  className,
}: {
  range?: DateRange
  onChange?: (r?: DateRange) => void
  className?: string
}) {
  const [open, setOpen] = React.useState(false)

  const label = range?.from && range?.to
    ? `${format(range.from, "LLL dd, y")} – ${format(range.to, "LLL dd, y")}`
    : "Pick a date range"

  const presets: Array<{ label: string; value: DateRange }> = [
    { label: "Last 7 days", value: { from: subDays(new Date(), 6), to: new Date() } },
    { label: "This week", value: { from: startOfWeek(new Date()), to: endOfWeek(new Date()) } },
  ]

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <Button variant="outline" className={cn("justify-between w-full", className)}>
          <span className="inline-flex items-center gap-2">
            <CalendarIcon className="h-4 w-4" />
            {label}
          </span>
          <ChevronDown className="h-4 w-4 opacity-60" />
        </Button>
      </PopoverTrigger>
      <PopoverContent className="w-auto p-0">
        <div className="p-2 grid grid-cols-2 gap-2">
          {presets.map((p) => (
            <Button key={p.label} size="sm" variant="secondary" onClick={() => onChange?.(p.value)}>
              {p.label}
            </Button>
          ))}
        </div>
        <Calendar
          mode="range"
          selected={range}
          onSelect={(r) => onChange?.(r ?? undefined)}
          initialFocus
        />
      </PopoverContent>
    </Popover>
  )
}
