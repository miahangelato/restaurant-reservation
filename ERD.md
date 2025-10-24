# Entity Relationship Diagram (ERD)

## Restaurant Reservation System Database Schema

```
┌─────────────────────────────────────┐
│            USERS                     │
├─────────────────────────────────────┤
│ PK │ id                    INTEGER  │
│    │ email                 STRING   │ UNIQUE, INDEXED
│    │ password_digest       STRING   │
│    │ name                  STRING   │
│    │ phone                 STRING   │
│    │ role                  STRING   │ DEFAULT: 'customer'
│    │ created_at           DATETIME  │
│    │ updated_at           DATETIME  │
└─────────────────────────────────────┘
         │
         │ has_many
         │
         ▼
┌─────────────────────────────────────┐
│          RESERVATIONS                │
├─────────────────────────────────────┤
│ PK │ id                    INTEGER  │
│ FK │ user_id               INTEGER  │ → users(id)
│ FK │ time_slot_id          INTEGER  │ → time_slots(id)
│ FK │ table_id              INTEGER  │ → tables(id) [OPTIONAL]
│    │ reservation_date      DATE     │
│    │ num_people            INTEGER  │
│    │ contact_name          STRING   │
│    │ contact_email         STRING   │
│    │ contact_phone         STRING   │
│    │ status                STRING   │ DEFAULT: 'confirmed'
│    │ created_at           DATETIME  │
│    │ updated_at           DATETIME  │
├─────────────────────────────────────┤
│ INDEXES:                             │
│  - [time_slot_id, reservation_date,  │
│     table_id]                        │
└─────────────────────────────────────┘
         │                    │
         │ belongs_to         │ belongs_to
         │                    │
         ▼                    ▼
┌─────────────────────┐  ┌─────────────────────┐
│    TIME_SLOTS       │  │      TABLES         │
├─────────────────────┤  ├─────────────────────┤
│ PK │ id      INTEGER│  │ PK │ id      INTEGER│
│    │ time    TIME   │  │    │ table_number    │
│    │ max_tables     │  │    │         STRING  │
│    │         INTEGER│  │    │ capacity        │
│    │ max_people_    │  │    │         INTEGER│
│    │  per_table     │  │    │ created_at      │
│    │         INTEGER│  │    │        DATETIME │
│    │ created_at     │  │    │ updated_at      │
│    │        DATETIME│  │    │        DATETIME │
│    │ updated_at     │  ├─────────────────────┤
│    │        DATETIME│  │ INDEXES:            │
├─────────────────────┤  │  - table_number     │
│ INDEXES:            │  │    (UNIQUE)         │
│  - time (UNIQUE)    │  └─────────────────────┘
└─────────────────────┘            │
         │                         │
         │ has_many                │ has_many
         │                         │
         └─────────┬───────────────┘
                   │
                   ▼
            (reservations)
```

## Relationship Details

### Users ↔ Reservations
- **Type**: One-to-Many
- **Details**: A user can have multiple reservations
- **Foreign Key**: `reservations.user_id` → `users.id`
- **On Delete**: Cascade (deleting user deletes their reservations)

### TimeSlots ↔ Reservations
- **Type**: One-to-Many
- **Details**: A time slot can have multiple reservations
- **Foreign Key**: `reservations.time_slot_id` → `time_slots.id`
- **On Delete**: Cascade (deleting time slot deletes associated reservations)

### Tables ↔ Reservations
- **Type**: One-to-Many
- **Details**: A table can have multiple reservations (different times/dates)
- **Foreign Key**: `reservations.table_id` → `tables.id` (optional)
- **On Delete**: Restrict with error (cannot delete table with confirmed reservations)

## Field Descriptions

### Users Table
- **id**: Primary key, auto-increment
- **email**: User's email address for login (unique, indexed)
- **password_digest**: Encrypted password using bcrypt
- **name**: Full name of the user
- **phone**: Contact phone number
- **role**: User role - either 'customer' or 'admin'
- **created_at**: Timestamp when user was created
- **updated_at**: Timestamp when user was last updated

### TimeSlots Table
- **id**: Primary key, auto-increment
- **time**: Time of the slot (e.g., 12:00, 18:00) - unique
- **max_tables**: Maximum number of tables bookable in this slot
- **max_people_per_table**: Maximum party size allowed per reservation
- **created_at**: Timestamp when slot was created
- **updated_at**: Timestamp when slot was last updated

### Tables Table
- **id**: Primary key, auto-increment
- **table_number**: Unique identifier for the table (e.g., "1", "A1")
- **capacity**: Maximum number of people the table can seat
- **created_at**: Timestamp when table was created
- **updated_at**: Timestamp when table was last updated

### Reservations Table
- **id**: Primary key, auto-increment
- **user_id**: Foreign key to users table
- **time_slot_id**: Foreign key to time_slots table
- **table_id**: Foreign key to tables table (optional, auto-assigned)
- **reservation_date**: Date of the reservation
- **num_people**: Number of people in the party
- **contact_name**: Name for the reservation
- **contact_email**: Email for reservation confirmation
- **contact_phone**: Phone number for contact
- **status**: Reservation status ('confirmed', 'pending', 'cancelled')
- **created_at**: Timestamp when reservation was created
- **updated_at**: Timestamp when reservation was last updated

## Business Logic Constraints

### At Application Level
1. **Email Validation**: Must be valid email format
2. **Password Security**: Minimum 6 characters, encrypted with bcrypt
3. **Advance Booking**: Reservations must be >= 2 hours in advance
4. **Cancellation Window**: Can only cancel >= 2 hours before reservation
5. **Date Validation**: Reservation date cannot be in the past
6. **Party Size**: Must not exceed time_slot.max_people_per_table
7. **Table Availability**: Cannot double-book same table/time/date
8. **Auto-Assignment**: System auto-assigns available table based on capacity

### At Database Level
1. **Unique Constraints**:
   - users.email
   - time_slots.time
   - tables.table_number

2. **Not Null Constraints**: All essential fields marked as NOT NULL

3. **Foreign Key Constraints**: Maintain referential integrity

4. **Index Optimization**:
   - users.email (for login lookups)
   - time_slots.time (for availability checks)
   - tables.table_number (for table lookups)
   - [time_slot_id, reservation_date, table_id] (for availability queries)

## Sample Data Relationships

```
User (customer@test.com)
  └── Reservation #1 (Oct 25, 2024)
        ├── TimeSlot (18:00)
        └── Table #5

Admin (admin@restaurant.com)
  └── Can manage:
        ├── All Reservations
        ├── All Time Slots
        └── All Tables
```

---

This ERD represents a normalized database design following Rails conventions and best practices for a restaurant reservation system.
