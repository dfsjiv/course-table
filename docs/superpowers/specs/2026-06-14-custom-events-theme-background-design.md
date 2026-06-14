# Custom Events, Theme, and Background Design

## Scope

Add three local-only features to CourseTable:

- Theme mode: follow system, light, or dark.
- Custom events: one-time or weekly recurring, with name, location, start/end time, and reminder.
- Background image: choose a local image, copy it into app storage, and control its visible opacity.

## User Experience

The app bar gains a settings button. Settings contains theme mode, background image selection/removal, and a background opacity slider.

The daily timetable gains a floating add button. Custom events appear with imported courses in chronological order and participate in next-event countdowns and notifications. Tapping a custom event opens edit/delete actions. Imported timetable courses remain read-only.

## Data

Custom events and appearance settings are stored locally. A weekly event repeats on the selected weekday. A one-time event appears only on its selected date. Background images are copied into app-owned storage so the app continues to display them after the original image moves.

## Reliability

Invalid event times are rejected. Deleting or editing an event reschedules notifications. Background loading failures fall back to the selected theme without blocking the timetable.

