// src/components/scheduling/DatePicker.tsx
"use client"

import * as React from "react"
import { Calendar } from "@/components/ui/calendar"
import { Popover, PopoverTrigger, PopoverContent } from "@/components/ui/popover"
import { Button } from "@/components/ui/button"
import { Calendar as CalendarIcon, ChevronDown } from "lucide-react"
import { format } from "date-fns"
import { cn } from "@/lib/utils"

type Preset = { label: string; getDate: () => Date }

const presets: Preset[] = [
  { label: "Today", getDate: () => new Date() },
  { label: "Yesterday", getDate: () => new Date(Date.now() - 86400000) },
]

export function DatePicker({
  date,
  onChange,
  className,
}: {
  date?: Date
  onChange?: (d?: Date) => void
  className?: string
}) {
  const [open, setOpen] = React.useState(false)

  const label = date ? format(date, "PPP") : "Pick a date"

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
            <Button key={p.label} size="sm" variant="secondary" onClick={() => onChange?.(p.getDate())}>
              {p.label}
            </Button>
          ))}
        </div>
        <Calendar
          mode="single"
          selected={date}
          onSelect={(d) => onChange?.(d)}
          initialFocus
        />
      </PopoverContent>
    </Popover>
  )
}
