---
name: custom-cal-com-creator
description: Create a Cal.com schedule with spotty PST availability and an event type.
---

## Quick Usage (Already Configured)

### 1) Configure env
- Copy `.env.example` to `.env` and fill values.
- If you want the skill to store credentials, add them to `.env` and rotate keys later.

### 2) Run scripts
```bash
bash .opencode/skills/custom-cal-com-creator/scripts/create-schedule.sh
bash .opencode/skills/custom-cal-com-creator/scripts/delete-default-availability.sh
bash .opencode/skills/custom-cal-com-creator/scripts/add-spotty-availability.sh
bash .opencode/skills/custom-cal-com-creator/scripts/create-event-type.sh
```

## Common Gotchas

- Availability times must be ISO strings like `1970-01-01T08:00:00.000Z`.
- Availabilities are weekly; they do not auto-expire after a single week.
- A new schedule defaults to a 9-5 weekday availability you may want to delete.

## First-Time Setup (If Not Configured)

1. Create a Cal.com API key in Settings > Security.
2. Copy `.env.example` to `.env` and fill in the minimum config.
3. The scripts infer what they can do from the values available in `.env`.

## Notes

- Use PST via `America/Los_Angeles` for the schedule time zone.
- Days are numbers: 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat, 0=Sun.
- `scripts/` uses `.env.example` as the minimum configuration reference.
