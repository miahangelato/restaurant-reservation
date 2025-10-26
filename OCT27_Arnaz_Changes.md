## Changelog — October 27, 2025

Author: Arnaz (work session)

Purpose: This document captures the changes made today to the `restaurant-reservation` application, explains why we made them, what each change does, and includes simple examples so other developers (including juniors) can replicate the approach.

---

## Summary of changes (high level)
We made several coordinated changes to support guest (anonymous) reservations, notification emails, UI clarity, and model-level rules. High-level changes include:

- Guest reservation support: allow creating reservations without a registered `User` (nullable `user_id`).
- Guest tokens: store a SHA256 digest of a one-time guest token plus an expiry time so guests can view their reservation via a special link.
- Mailer updates: `ReservationMailer` now sends confirmation emails that include the one-time guest token link.
- Controller flow changes: `ReservationsController#create` prepares a token for guests, sends email, and redirects guests to a tokenized `show` URL; authorization was tightened so guests can only view (`show`) but cannot edit/cancel.
- UX: added a clear guest information banner on the reservation form, removed the "Got it" dismiss button so guests can't miss the instructions, and disabled Turbo for the form to avoid the previously observed modal/Turbo race.
- Tests: added unit/controller/mailer/system tests to cover the guest flows and validations.

Files changed today (summary):
- `db/migrate/20251027000001_make_user_nullable_on_reservations.rb`
- `db/migrate/20251027000002_add_guest_token_to_reservations.rb`
- `db/migrate/20251027000005_add_cancelled_at_to_reservations.rb`
- `app/models/reservation.rb`
- `app/controllers/reservations_controller.rb`
- `app/mailers/reservation_mailer.rb` and `app/views/reservation_mailer/*`
- `app/views/reservations/new.html.erb`, `show.html.erb`, `index.html.erb`
- `config/initializers/reservation_settings.rb`, `config/initializers/smtp_settings.rb`
- `config/environments/development.rb`, `config/database.yml`, `config/routes.rb`
- `app/javascript/controllers/guest_reservation_modal_controller.js` (created during experimentation; not used in final flow)
- tests: multiple files under `test/*` (model, controller, mailer, system tests)

---

Why we did this
- The guest banner contains important information for unregistered users: they will receive a one-time email link and they cannot edit or cancel their reservation. Allowing guests to dismiss this message risks them missing critical guidance. Removing the dismiss button ensures all guests see the message while they are on the reservation form. This is a UX decision to reduce confusion.

Files changed (today)
- `app/views/reservations/new.html.erb`
	- The guest information banner markup was updated: the dismiss button ("Got it") was removed and a short comment left in the file to explain the removal.

---

## Detailed explanation (beginner friendly)

Below is a walkthrough of the exact change we made and why. I assume you have a basic understanding of Rails views and HTML.

1) Location in repo

- File: `app/views/reservations/new.html.erb`
- This view renders the "Make a Reservation" page (the form users fill out to create a reservation).

2) What the banner is

- We render a Bootstrap-styled alert when `current_user` is nil (i.e., a guest/anonymous visitor).
- The alert tells the guest they will receive a one-time link by email and clarifies guests cannot edit/cancel reservations.

3) Original behavior vs new behavior

- Original: the alert included a small "Got it" button (a dismiss button) that removed the alert via an inline onclick handler: `onclick=\"this.closest('.alert').remove()\"`.
- Change made today: the dismiss button markup was removed completely so the banner is no longer dismissible.

4) Why removing the button matters (UX & safety)

- Primary: The banner contains essential information that the guest needs to know during booking.
- Secondary: Dismissing the banner might lead to repeated support questions, or guests not realizing they need to check email for a special token link.

5) Exact code changes (what was removed)

- We removed the following snippet (conceptual):

	<button type=\"button\" class=\"btn btn-sm btn-link text-decoration-none\" aria-label=\"Dismiss notice\" onclick=\"this.closest('.alert').remove()\">Got it</button>

- And replaced it with a short comment in the view to make the intent explicit for future developers:

	<!-- Dismiss button removed per design: guests should see the banner until they navigate away -->

6) Small note about positioning (previous intermediate change)

- Earlier in the day we had adjusted the layout so the dismiss button would sit in the top-right using Bootstrap utility classes: `ms-auto align-self-start`. That change improved the positioning when the button was present, but since the dismissal was removed the layout now relies on the existing banner flow and the comment documents the previous intent for maintainers.

---

## Full list of changes (file-by-file, with explanations)

Below we expand the changes to include code-level explanations and examples so a junior developer can understand the intent and reproduce similar features.

1) Database migrations

- `db/migrate/20251027000001_make_user_nullable_on_reservations.rb`
	- Purpose: allow `reservations.user_id` to be NULL for guest-created reservations.
	- Why: guests don't have a User record; making `user_id` nullable avoids forcing guest accounts.
	- Example migration snippet:

```ruby
class MakeUserNullableOnReservations < ActiveRecord::Migration[7.0]
	def change
		change_column_null :reservations, :user_id, true
	end
end
```

- `db/migrate/20251027000002_add_guest_token_to_reservations.rb`
	- Purpose: add `guest_token_digest:string` and `guest_token_expires_at:datetime` so the app can validate tokens without storing plain text.
	- Why: security — store a digest (SHA256) rather than the raw token.
	- Example migration snippet:

```ruby
class AddGuestTokenToReservations < ActiveRecord::Migration[7.0]
	def change
		add_column :reservations, :guest_token_digest, :string
		add_column :reservations, :guest_token_expires_at, :datetime
		add_index :reservations, :guest_token_digest
	end
end
```

- `db/migrate/20251027000005_add_cancelled_at_to_reservations.rb`
	- Purpose: add a `cancelled_at` timestamp to mark cancellations without deleting rows.
	- Why: preserves audit history and avoids destructive deletes.

2) `app/models/reservation.rb`

- Key changes and why:
	- `belongs_to :user, optional: true` — allow guest reservations.
	- `prepare_guest_token!(expiry_days: 7)` — prepare a one-time token (returns plain token) and set digest + expiry on the model (does not persist by default; controller saves after build).
	- `valid_guest_token?(token)` — validates an incoming token by computing SHA256 digest and comparing with stored digest, and checks expiry.
	- `cancel!` or `mark_cancelled` — sets `cancelled_at = Time.current` and queues cancellation email.

- Example implementations (illustrative — matches what was added):

```ruby
class Reservation < ApplicationRecord
	belongs_to :user, optional: true

	# Prepares a plain-text one-time token and sets digest + expiry on the instance.
	# Returns the plain token so caller can send it by email.
	def prepare_guest_token!(expiry_days: 7)
		token = SecureRandom.urlsafe_base64(24)
		self.guest_token_digest = Digest::SHA256.hexdigest(token)
		self.guest_token_expires_at = Time.current + expiry_days.days
		token
	end

	# Validates a plain token against the stored digest and expiry
	def valid_guest_token?(plain_token)
		return false if guest_token_digest.blank? || guest_token_expires_at.blank?
		return false if Time.current > guest_token_expires_at
		Digest::SHA256.hexdigest(plain_token) == guest_token_digest
	end

	# Mark reservation cancelled (soft delete approach)
	def cancel!
		update!(cancelled_at: Time.current, status: 'cancelled')
		# optionally: enqueue cancellation email
	end
end
```

Notes for juniors:
- We never store the plain token server-side long-term. We only store a SHA256 digest. This means that when we email the token, the app (controller) must capture the plain token and include it in the email immediately.
- If an attacker reads the DB, they cannot recover the plain token from the stored digest.

3) `app/controllers/reservations_controller.rb`

- Key behavior added:
	- The `create` action now supports anonymous users. If `current_user` is nil, the controller:
		1. Builds the Reservation from form params.
		2. Calls `prepare_guest_token!` on the model to get a plain token.
		3. Saves the reservation (persisting the digest/expires fields).
		4. Sends `ReservationMailer.confirmation_email` with the plain token (via `deliver_later`).
		5. Redirects the guest to the reservation `show` URL containing the `guest_token` query param, so they can immediately view the reservation.

- Authorization adjustments:
	- `authorize_reservation` was tightened: guests may only access `show` when they provide a valid guest token; edit/update/destroy actions require owner or admin.

- Example flow in `create` (pseudocode):

```ruby
def create
	@reservation = Reservation.new(reservation_params)
	if current_user
		@reservation.user = current_user
		@reservation.save!
		# regular registered-user flow
	else
		guest_token = @reservation.prepare_guest_token!
		@reservation.save!
		ReservationMailer.with(reservation: @reservation, guest_token: guest_token).confirmation_email.deliver_later
		redirect_to reservation_url(@reservation, guest_token: guest_token)
	end
end
```

4) `app/mailers/reservation_mailer.rb` and views

- Purpose: send confirmation email with a one-time link containing the plain `guest_token` query param.
- Implementation notes:
	- The mailer reads `params[:guest_token]` (or an explicit argument) and uses it to generate a URL:

```ruby
def confirmation_email
	@reservation = params[:reservation]
	@guest_token = params[:guest_token]
	@manage_url = reservation_url(@reservation, guest_token: @guest_token)
	mail(to: @reservation.contact_email, subject: "Your reservation confirmation")
end
```

- Mail templates (`app/views/reservation_mailer/confirmation_email.html.erb` and `.text.erb`) include the `@manage_url` and explain guests cannot edit/cancel.

5) Views changed

- `app/views/reservations/new.html.erb`
	- Added a guest info banner that only renders when `current_user` is nil.
	- Disabled `turbo` on the `form_with` (data: { turbo: false }) to avoid Turbo modal race conditions encountered earlier.
	- Removed the dismissible "Got it" button per today's decision.
	- Used safe navigation (`current_user&.email`) when prefilling contact fields.

- `app/views/reservations/show.html.erb`
	- Conditional rendering: if the viewer is a guest (validated via token), do not show Edit / Cancel actions. Show an informational note instead.

- `app/views/reservations/index.html.erb`
	- UI cleanup: removed duplicate "View Details" links and ensured guest-created reservations render even if `user` is nil.

6) JavaScript

- `app/javascript/controllers/guest_reservation_modal_controller.js`
	- We experimented with a Stimulus controller that showed a pre-submit modal warning. This caused a fragile interaction with Turbo and sometimes produced a blank page. After testing, we removed modal interception from the form submission path and rely on a stable inline banner instead.
	- Recommendation: delete this file if we won't reintroduce modal behavior, or refactor it later to simply manage a `localStorage` dismissible banner (see examples below).

7) Initializers and config

- `config/initializers/reservation_settings.rb`
	- Small app-level constants (for example `RESERVATION_MIN_ADVANCE_HOURS = 2`) so business rules are centralized.

- `config/initializers/smtp_settings.rb` and `config/environments/development.rb`
	- Configured ActionMailer SMTP settings for development. Use environment variables and Rails credentials for any secret values. Do not commit credentials to source control.

8) Routes

- `config/routes.rb`
	- May include a `collection` route for availability and accept `guest_token` as a query param on `reservations#show`. No major route changes required beyond ensuring `reservation_url(@reservation, guest_token: token)` resolves.

9) Tests added

- `test/models/reservation_advance_validation_test.rb` — ensures reservations must be made at least N hours in advance.
- `test/models/reservation_cancellation_test.rb` — tests cancellation behavior (soft-cancel and notifications).
- `test/models/reservation_mailer_enqueue_test.rb` — assert mailer enqueues confirmation on create.
- `test/controllers/reservations_controller_test.rb` — asserts session cleanup and controller flows for cancel.
- `test/mailers/reservation_mailer_test.rb` and `test/mailers/reservation_cancellation_mailer_test.rb` — mailer tests for content and recipients.
- System tests under `test/system/*` — end-to-end flows for confirmation and cancellation.

---

## Helpful examples & quick recreations (mini-tutorials)

1) Generate and store a guest token (model-level)

```ruby
# in rails console or controller
reservation = Reservation.new(contact_email: 'guest@example.com', reservation_date: Date.tomorrow)
plain_token = reservation.prepare_guest_token!(expiry_days: 7)
reservation.save!
puts "Email this link to guest: #{Rails.application.routes.url_helpers.reservation_url(reservation, guest_token: plain_token)}"
```

2) Validate a guest token (controller-level)

```ruby
reservation = Reservation.find(params[:id])
if reservation.valid_guest_token?(params[:guest_token])
	# allow viewing
else
	head :forbidden
end
```

3) Send confirmation email from controller

```ruby
guest_token = @reservation.prepare_guest_token!
@reservation.save!
ReservationMailer.with(reservation: @reservation, guest_token: guest_token).confirmation_email.deliver_later
redirect_to reservation_url(@reservation, guest_token: guest_token)
```

---

## Professional advice & improvements (actionable)

Short-term / High priority

- Add a focused system test that simulates the guest booking flow: create a guest reservation, assert an email was enqueued, follow the emailed link, assert guest can view but cannot cancel/edit.
- Audit `config/database.yml` and `config/initializers/smtp_settings.rb` for secrets. Move credentials to Rails encrypted credentials or environment variables.

Medium-term

- Hardening tokens: consider rotating/invalidating tokens after first use (one-time tokens) and logging token usage for audit. Optionally store a `guest_token_used_at` timestamp when a guest uses the link.
- Add rate-limiting on token validation endpoints to avoid brute force.
- Update admin dashboard to ensure guest-created reservations (where `user_id` is NULL) are visible and filterable. Add tests to verify behavior.

Long-term / Nice-to-have

- Color-code time slots in the UI based on availability (e.g., green for many seats, amber for limited, red for full). This helps users choose less-congested times. Implement by calculating capacity per `TimeSlot` and returning an availability status (enum) to the view.
- If you want dismissal for returning guests, implement a small Stimulus controller that stores dismissal in `localStorage` and respects accessibility (keyboard & screen readers). Keep server-side behavior unchanged for guests.

Housekeeping

- Remove unused JS (`guest_reservation_modal_controller.js`) if it's not used to reduce confusion.
- Add/ensure `.gitignore` contains `vendor/bundle/` and any local-only files.

---

## Noted by Arnaz — TODOs & follow-ups

- UI improvement (optional)
- Calendar hasn't been touched yet.
- Color code time slots based on availability (visual improvement that helps users pick uncongested slots).
- Viewing of all reservations specifically for Admin Dashboard. Make sure that all reservations are being shown, including reservations created by guest users (i.e., `user_id` may be NULL). This might require a controller/SQL adjustment to include rows where `user_id IS NULL` and a filter for guest vs registered users.

Example admin query (ActiveRecord) to ensure guest reservations are included:

```ruby
# in Admin::ReservationsController#index
@reservations = Reservation.all.order(reservation_date: :desc, time_slot_id: :asc)

# If you previously accidentally filtered by presence of user, remove that clause;
# for example: remove `.where.not(user_id: nil)` if it exists.
```

---

## Quick verification steps (how to check the change locally)
1. Start the Rails server:

```powershell
bin\\dev
```

2. Visit: `http://localhost:3000/reservations/new` as an anonymous user (log out or open an incognito window).
3. Create a guest reservation and check that an email was enqueued (or inspect logs) and that the redirect goes to a URL containing `?guest_token=...`.
4. Open the emailed link (or paste the token into the browser) and confirm the reservation is visible but Edit/Cancel actions are hidden.

---

If you'd like, I can also:
- add a simple system test asserting the absence of the dismiss button,
- implement a `localStorage`-based dismissible variant (with ARIA and keyboard support), or
- add the admin-side fix to ensure guest reservations are visible in the admin dashboard.

Marking this document as: Noted by Arnaz

---

End of changelog for Oct 27, 2025


## How to recreate this change (step-by-step example)

If you want to remove a dismiss button from any Bootstrap alert in a Rails view, follow these simple steps.

1) Open the view that contains the alert. Example path:

```
app/views/reservations/new.html.erb
```

2) Find the alert markup. For example it may look like:

```erb
<div class=\"alert alert-info\"> 
	<div class=\"d-flex\"> 
		<div class=\"flex-grow-1\"> ... message ... </div> 
		<div> 
			<button type=\"button\" class=\"btn btn-sm btn-link\" onclick=\"this.closest('.alert').remove()\">Got it</button>
		</div>
	</div>
</div>
```

3) Remove the `<button>` block and its containing wrapper. Optionally, add a comment for future maintainers:

```erb
<div class=\"alert alert-info\"> 
	<div class=\"d-flex\"> 
		<div class=\"flex-grow-1\"> ... message ... </div> 
		<!-- Dismiss button removed per design: guests should see the banner until they navigate away -->
	</div>
</div>
```

4) Save and reload the page in your browser. The alert will remain visible until the user navigates away or refreshes (no client-side removal anymore).

Notes and alternatives
- If you want a non-destructive dismiss that persists a user's preference (for example not show the banner again on subsequent visits), implement a JavaScript-based solution that sets an entry in `localStorage` (client-side) or in a small cookie and then checks that value before rendering the banner. That approach is more user-friendly for returning users but requires careful thought for accessibility and cross-device behavior.

Example: simple localStorage approach (client-side only)

1) Add a small script (Stimulus controller or inline JS):

```js
// Pseudocode — keep this accessible and test keyboard users
document.addEventListener('click', (e) => {
	if (e.target.matches('.js-dismiss-banner')) {
		localStorage.setItem('hideGuestBanner', 'true');
		document.querySelector('.guest-banner')?.remove();
	}
});

// On page load (server-side render can also check this via cookie)
if (localStorage.getItem('hideGuestBanner') === 'true') {
	// hide banner via CSS or don't render it client-side
}
```

2) Accessibility: make sure the dismissal control is reachable by keyboard and has an appropriate accessible name (e.g., `aria-label`).

---

## Professional advice & improvements

Short-term (low-risk)
- Add a small system test to assert the presence (or absence) of the dismiss button depending on the desired behavior. This prevents accidental re-introduction.
- If we want to allow dismissal for returning users, prefer a `localStorage` or cookie-based approach and clearly document the behavior.

Medium-term (recommended)
- Accessibility: add ARIA roles and test the banner with a screen reader flow. Consider focusing an announcement or ensuring it doesn't disrupt form navigation.
- UI polish: consider a slightly smaller banner for mobile or use collapsible pattern so long messages don't push the form down on smaller screens.

Long-term (optional)
- Consider letting registered users dismiss the banner permanently by storing the preference server-side (in the user profile). For guests, prefer client-side persistence.

Security and data considerations
- No sensitive data is in the banner. If you later introduce actions (e.g., resend token) link those back-end endpoints to proper rate-limiting and CSRF protections.

---

## Noted by Arnaz — TODOs & follow-ups

- UI improvement (optional)
- Calendar hasn't been touched yet.
- Color code time slots based on availability (visual improvement that helps users pick uncongested slots).
- Viewing of all reservations specifically for Admin Dashboard. Make sure that all reservations are being shown, including reservations created by guest users (i.e., `user_id` may be NULL). This might require a controller/SQL adjustment to include rows where `user_id IS NULL` and a filter for guest vs registered users.

Example admin query (ActiveRecord) to ensure guest reservations are included:

```ruby
# in Admin::ReservationsController#index
@reservations = Reservation.all.order(reservation_date: :desc, time_slot_id: :asc)

# If you previously accidentally filtered by presence of user, remove that clause;
# for example: remove `.where.not(user_id: nil)` if it exists.
```

---

## Quick verification steps (how to check the change locally)
1. Start the Rails server:

```powershell
bin\\dev
```

2. Visit: `http://localhost:3000/reservations/new` as an anonymous user (log out or open an incognito window).
3. Confirm the guest info banner is visible and that there is no "Got it" dismiss button. The banner should remain visible until you navigate away.

---

If you'd like, I can also:
- add a simple system test asserting the absence of the dismiss button,
- implement a `localStorage`-based dismissible variant (with ARIA and keyboard support), or
- add the admin-side fix to ensure guest reservations are visible in the admin dashboard.

Marking this document as: Noted by Arnaz

---

End of changelog for Oct 27, 2025

