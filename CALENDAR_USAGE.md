# Calendar View - Usage Guide

## Accessing the Calendar

### Direct URLs
- **Main Calendar Page**: `/reservations/calendar`
- **Calendar for Specific Month**: `/reservations/calendar?date=2025-11-15`

### Navigation Links
- From "My Reservations" page: Click "📅 View Calendar" button
- From "Make a Reservation" page: Click "📅 View Calendar" button
- From "Check Availability" page: Click "📅 Calendar View" button

## Calendar Display

### Month View
```
        October 2025
Sun  Mon  Tue  Wed  Thu  Fri  Sat
          1    2    3    4    5    (dates shown with availability)
 6    7    8    9   10   11   12
13   14   15   16   17   18   19
20   21   22   23   24   25   26
27   28   29   30   31
```

### Date Card Information
Each date card shows:
- **Date number** (top left)
- **Availability count** (e.g., "3/5 slots" means 3 out of 5 time slots have availability)
- **"View Times" button** to see detailed time information
- **Color indication** of availability status

### Color Legend
| Color | Status | Meaning |
|-------|--------|---------|
| 🟢 Green | Available | Can book a reservation |
| 🔴 Red | Fully Booked | All time slots are taken |
| ⚫ Gray | Past Date | Cannot book (date has passed) |

## Interactive Features

### Viewing Time Slots
1. Find a date you're interested in
2. Click "View Times" button on the date card
3. A modal window opens showing all available time slots for that date
4. Each time slot shows:
   - Time (e.g., "06:00 PM")
   - Capacity per table (e.g., "Max 4 people per table")
   - Availability status (✅ with table count or ❌ Fully Booked)

### Making a Reservation
From the time slots modal:
1. Review available times
2. Click "Make a Reservation" button
3. You'll be taken to the reservation form with the date pre-selected
4. Choose a time slot and complete the booking

### Navigating Months
- Click **"← Previous"** button to view previous month
- Click **"Next →"** button to view next month
- Buttons are disabled when you reach the date range limits
- Valid booking dates: Today through 3 months ahead

## Calendar Statistics

The bottom of the calendar shows:
- **📊 Days with Availability** - Count of days in the current month with at least one available time slot
- **📅 Total Time Slots** - Total number of different time slots offered daily
- **⏰ Booking Window** - Shows the booking range (3 months ahead)

## Example Workflows

### Workflow 1: Book a Reservation
```
1. Start on "My Reservations" page
2. Click "📅 View Calendar"
3. Browse to desired month (use Previous/Next)
4. Click "View Times" on preferred date
5. Review available times in modal
6. Click "Make a Reservation"
7. Select time slot from form (pre-filled with date)
8. Enter party size and contact info
9. Confirm reservation
```

### Workflow 2: Check Multiple Dates
```
1. Open calendar
2. Click "View Times" on first date
3. Review options (modal stays in background)
4. Close modal (X button or click outside)
5. Repeat for other dates
6. Decide on best option and book
```

### Workflow 3: Browse Months Ahead
```
1. Open calendar (starts with current month)
2. Click "Next →" to see next month
3. Click "Next →" again for month after
4. Continue browsing up to 3 months ahead
5. Return to desired month when found
6. Book a time slot
```

## Technical Features

### Data Updates
- Calendar data is calculated fresh on each page load
- Takes real-time reservations into account
- Shows current availability status

### Performance
- Efficient calendar generation using Ruby ranges
- Minimal database queries (one per time slot per date)
- Fast rendering of 30+ dates

### Accessibility
- Keyboard navigable
- Bootstrap modals with proper focus management
- Color-coded indicators with text labels (not just color)
- Responsive design for all screen sizes

## Browser Compatibility
- Modern browsers (Chrome, Firefox, Safari, Edge)
- Bootstrap 5.1.3 support
- Mobile browsers fully supported
- Touch-friendly interface

## Notes
- Past dates are shown but cannot be booked
- Time slots reflect maximum capacity constraints
- Availability updates when new reservations are confirmed
- System enforces 2-hour advance booking requirement
- Reservations within 2 hours of start time show as "Fully Booked"
