# Patient Listing Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the default patients page with a "Today" segment showing today's appointments, while preserving the existing alphabetical listing as an "All patients" segment.

**Architecture:** Add a `today_for_practice` scope on Appointment using `eager_load`. Restructure `PatientsController#index` to route between segments based on params. Add Tabler `nav-pills` to the view with a new `_today_patient.html.erb` partial for the Today rows. Remove `updated_at` column from the All patients listing.

**Tech Stack:** Ruby on Rails, Minitest, Tabler UI, ERB views, PostgreSQL

**Spec:** `docs/superpowers/specs/2026-03-21-patient-listing-redesign.md`

---

### Task 1: Add `today_for_practice` scope to Appointment model

**Files:**
- Modify: `app/models/appointment.rb`
- Test: `test/models/appointment_test.rb` (create if needed)

- [ ] **Step 1: Write the failing test**

Create `test/models/appointment_test.rb` if it doesn't exist, or add to it:

```ruby
test 'today_for_practice returns only todays confirmed and waiting appointments for practice' do
  practice = practices(:complete)
  doctor = doctors(:rebecca)
  datebook = datebooks(:playa_del_carmen)

  patient = Patient.create!(
    practice: practice, firstname: 'Test', lastname: 'Today',
    uid: 'TODAY01', date_of_birth: Date.new(1990, 1, 1)
  )

  # Today's confirmed appointment
  today_confirmed = Appointment.create!(
    datebook: datebook, doctor: doctor, patient: patient,
    starts_at: Time.current.change(hour: 10), ends_at: Time.current.change(hour: 10, min: 30),
    status: Appointment.status[:confirmed]
  )

  # Today's waiting room appointment
  today_waiting = Appointment.create!(
    datebook: datebook, doctor: doctor, patient: patient,
    starts_at: Time.current.change(hour: 11), ends_at: Time.current.change(hour: 11, min: 30),
    status: Appointment.status[:waiting_room]
  )

  # Today's cancelled appointment (should be excluded)
  Appointment.create!(
    datebook: datebook, doctor: doctor, patient: patient,
    starts_at: Time.current.change(hour: 14), ends_at: Time.current.change(hour: 14, min: 30),
    status: Appointment.status[:cancelled]
  )

  # Yesterday's confirmed appointment (should be excluded)
  Appointment.create!(
    datebook: datebook, doctor: doctor, patient: patient,
    starts_at: 1.day.ago.change(hour: 10), ends_at: 1.day.ago.change(hour: 10, min: 30),
    status: Appointment.status[:confirmed]
  )

  results = Appointment.today_for_practice(practice.id, practice.timezone)
  result_ids = results.map(&:id)

  assert_includes result_ids, today_confirmed.id
  assert_includes result_ids, today_waiting.id
  assert_equal 2, result_ids.count { |id| [today_confirmed.id, today_waiting.id].include?(id) }
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/appointment_test.rb -n "test_today_for_practice"`
Expected: FAIL or ERROR — `NoMethodError: undefined method 'today_for_practice'`

- [ ] **Step 3: Write the scope**

Add to `app/models/appointment.rb` after the existing scopes (around line 17):

```ruby
scope :today_for_practice, ->(practice_id, timezone) {
  tz = ActiveSupport::TimeZone[timezone] || Time.zone
  today_start = tz.now.beginning_of_day
  today_end = tz.now.end_of_day

  eager_load(:patient, :doctor)
    .where(patients: { practice_id: practice_id })
    .where(status: [status[:confirmed], status[:waiting_room]])
    .where(starts_at: today_start..today_end)
    .order(:starts_at)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/models/appointment_test.rb -n "test_today_for_practice"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/models/appointment.rb test/models/appointment_test.rb
git commit -m "feat(appointments): add today_for_practice scope"
```

---

### Task 2: Add I18n keys to all three locales

**Files:**
- Modify: `config/locales/en.yml`
- Modify: `config/locales/es.yml`
- Modify: `config/locales/pt.yml`

- [ ] **Step 1: Add English keys**

Add to `config/locales/en.yml` (alphabetically, near other patient keys):

```yaml
  appointment_status_confirmed: Confirmed
  appointment_status_waiting: In waiting room
  appointment_time_duration: "%{time} (%{duration} min)"
  patients_segment_all: All patients
  patients_segment_today: Today
  patients_today_empty: No appointments today
  patients_today_empty_hint: View all patients
```

- [ ] **Step 2: Add Spanish keys**

Add to `config/locales/es.yml`:

```yaml
  appointment_status_confirmed: Confirmada
  appointment_status_waiting: En sala de espera
  appointment_time_duration: "%{time} (%{duration} min)"
  patients_segment_all: Todos los pacientes
  patients_segment_today: Hoy
  patients_today_empty: Sin citas para hoy
  patients_today_empty_hint: Ver todos los pacientes
```

- [ ] **Step 3: Add Portuguese keys**

Add to `config/locales/pt.yml`:

```yaml
  appointment_status_confirmed: Confirmada
  appointment_status_waiting: Na sala de espera
  appointment_time_duration: "%{time} (%{duration} min)"
  patients_segment_all: Todos os pacientes
  patients_segment_today: Hoje
  patients_today_empty: Sem consultas hoje
  patients_today_empty_hint: Ver todos os pacientes
```

- [ ] **Step 4: Verify keys load without errors**

Run: `bin/rails runner "puts I18n.t(:patients_segment_today, locale: :en), I18n.t(:patients_segment_today, locale: :es), I18n.t(:patients_segment_today, locale: :pt)"`
Expected: `Today`, `Hoy`, `Hoje`

- [ ] **Step 5: Commit**

```bash
git add config/locales/en.yml config/locales/es.yml config/locales/pt.yml
git commit -m "feat(i18n): add patient listing segment translations"
```

---

### Task 3: Add helper methods for segment pills and appointment formatting

**Files:**
- Modify: `app/helpers/patients_helper.rb`
- Test: `test/unit/patients_helper_test.rb`

- [ ] **Step 1: Write failing tests for the pill helper**

Add to `test/unit/patients_helper_test.rb`:

```ruby
test 'patients_segment_pills renders today pill as active with count' do
  @segment = 'today'
  @today_count = 5

  result = patients_segment_pills
  assert_includes result, 'nav-pills'
  assert_includes result, 'active'
  assert_includes result, 'Today'
  assert_includes result, '5'
end

test 'patients_segment_pills renders all patients pill as active' do
  @segment = 'all'
  @today_count = 3

  result = patients_segment_pills
  # "All patients" pill should be active
  assert_match(/nav-link active.*All patients/m, result)
end

test 'appointment_time_with_duration formats start time and duration' do
  starts_at = Time.zone.parse('2026-03-21 10:30:00')
  ends_at = Time.zone.parse('2026-03-21 11:00:00')

  result = appointment_time_with_duration(starts_at, ends_at)
  assert_includes result, '30 min'
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/unit/patients_helper_test.rb`
Expected: FAIL — undefined methods

- [ ] **Step 3: Implement helper methods**

Add to `app/helpers/patients_helper.rb`:

```ruby
def patients_segment_pills
  content_tag(:ul, class: 'nav nav-pills mb-3') do
    today_pill = content_tag(:li, class: 'nav-item') do
      link_to patients_url(segment: 'today'),
              class: "nav-link #{@segment == 'today' ? 'active' : ''}" do
        badge = content_tag(:span, @today_count, class: 'badge ms-1')
        "#{t(:patients_segment_today)} #{badge}".html_safe
      end
    end

    all_pill = content_tag(:li, class: 'nav-item') do
      link_to t(:patients_segment_all),
              patients_url(segment: 'all'),
              class: "nav-link #{@segment == 'all' ? 'active' : ''}"
    end

    today_pill + all_pill
  end
end

def appointment_time_with_duration(starts_at, ends_at)
  time = starts_at.strftime('%l:%M %p').strip
  duration = ((ends_at - starts_at) / 60).round
  t(:appointment_time_duration, time: time, duration: duration)
end

def appointment_status_label(status)
  case status
  when Appointment.status[:confirmed]
    content_tag(:span, t(:appointment_status_confirmed), class: 'text-green')
  when Appointment.status[:waiting_room]
    content_tag(:span, t(:appointment_status_waiting), class: 'text-yellow')
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/unit/patients_helper_test.rb`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/helpers/patients_helper.rb test/unit/patients_helper_test.rb
git commit -m "feat(helpers): add segment pill and appointment formatting helpers"
```

---

### Task 4: Restructure controller index action with segment routing

**Files:**
- Modify: `app/controllers/patients_controller.rb`
- Test: `test/functional/patients_controller_test.rb`

- [ ] **Step 1: Write failing tests for the Today segment**

Add to `test/functional/patients_controller_test.rb`:

```ruby
test 'index defaults to today segment' do
  get :index
  assert_response :success
  assert_equal 'today', assigns(:segment)
end

test 'today segment shows only todays confirmed and waiting appointments' do
  practice = practices(:complete)
  doctor = doctors(:rebecca)
  datebook = datebooks(:playa_del_carmen)

  patient = Patient.create!(
    practice: practice, firstname: 'Visit', lastname: 'Today',
    uid: 'VT001', date_of_birth: Date.new(1990, 1, 1)
  )

  today_appt = Appointment.create!(
    datebook: datebook, doctor: doctor, patient: patient,
    starts_at: Time.current.change(hour: 10), ends_at: Time.current.change(hour: 10, min: 30),
    status: Appointment.status[:confirmed]
  )

  yesterday_appt = Appointment.create!(
    datebook: datebook, doctor: doctor, patient: patient,
    starts_at: 1.day.ago.change(hour: 10), ends_at: 1.day.ago.change(hour: 10, min: 30),
    status: Appointment.status[:confirmed]
  )

  cancelled_appt = Appointment.create!(
    datebook: datebook, doctor: doctor, patient: patient,
    starts_at: Time.current.change(hour: 14), ends_at: Time.current.change(hour: 14, min: 30),
    status: Appointment.status[:cancelled]
  )

  get :index
  appointment_ids = assigns(:appointments).map(&:id)

  assert_includes appointment_ids, today_appt.id
  refute_includes appointment_ids, yesterday_appt.id
  refute_includes appointment_ids, cancelled_appt.id
end

test 'today segment empty state' do
  get :index
  assert_response :success
  assert_equal 'today', assigns(:segment)
  # No appointments created for today, so list should be empty
  assert assigns(:appointments).empty? || assigns(:appointments).none? { |a| a.starts_at.to_date == Date.current }
end

test 'all segment preserves existing letter behavior' do
  get :index, params: { segment: 'all' }
  assert_response :success
  assert_equal 'all', assigns(:segment)
  assert_not_nil assigns(:patients)
  assert_not_nil assigns(:current_letter)
end

test 'letter param infers all segment' do
  get :index, params: { letter: 'A' }
  assert_response :success
  assert_equal 'all', assigns(:segment)
end

test 'segment pills not shown during search' do
  get :index, params: { term: 'test' }
  assert_response :success
  assert_nil assigns(:segment)
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/functional/patients_controller_test.rb`
Expected: FAIL — `assigns(:segment)` is nil, `assigns(:appointments)` is nil

- [ ] **Step 3: Restructure the index action**

Replace the `index` method in `app/controllers/patients_controller.rb` (lines 13-39):

```ruby
def index
  if params[:term].present?
    @patients = with_last_visit_for_listing(
      Patient.search(params[:term]).with_practice(current_user.practice_id)
    )
  elsif params[:segment].present? && params[:segment] == 'new_this_week'
    # Align with KPI: use practice timezone and current calendar week (Mon–Sun), inclusive
    tz = ActiveSupport::TimeZone[current_user.practice.timezone] || Time.zone
    week_start = tz.now.beginning_of_week
    week_end = tz.now.end_of_week
    @patients = with_last_visit_for_listing(
      Patient
        .with_practice(current_user.practice_id)
        .where('created_at >= ? AND created_at <= ?', week_start, week_end)
    )
  elsif infer_all_segment?
    @segment = 'all'
    resolve_letter_context
  else
    @segment = 'today'
    resolve_today_context
  end

  @patients ||= [] # guard for json/js formats when on Today segment

  respond_to do |format|
    format.html # index.html
    format.json do
      render json: @patients, methods: :fullname
    end
    format.js
  end
end
```

Add the new private methods:

```ruby
def resolve_today_context
  practice = current_user.practice
  @appointments = Appointment.today_for_practice(practice.id, practice.timezone)
  @today_count = @appointments.size
end

def infer_all_segment?
  params[:segment] == 'all' ||
    params[:letter].present? ||
    params[:sort].present? ||
    params[:cursor].present?
end
```

Also add a method to compute the today count for the pill badge, and call it from `resolve_letter_context`:

```ruby
def today_appointment_count
  practice = current_user.practice
  tz = ActiveSupport::TimeZone[practice.timezone] || Time.zone

  Appointment
    .joins(:patient)
    .where(patients: { practice_id: practice.id })
    .where(status: [Appointment.status[:confirmed], Appointment.status[:waiting_room]])
    .where(starts_at: tz.now.beginning_of_day..tz.now.end_of_day)
    .count
end
```

In `resolve_letter_context`, add at the top: `@today_count = today_appointment_count`

Note: This uses `joins` (not `eager_load`) and `count` — Rails optimizes to `SELECT COUNT(*)` so no records are loaded.

- [ ] **Step 4: Update the existing 'should get index' test**

The existing test at line 17-21 does `GET /patients` with no params. After the change, it hits the Today segment. Update it:

```ruby
test 'should get index' do
  get :index
  assert_response :success
  assert_equal 'today', assigns(:segment)
end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/functional/patients_controller_test.rb`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add app/controllers/patients_controller.rb test/functional/patients_controller_test.rb
git commit -m "feat(patients): restructure index action with today/all segment routing"
```

---

### Task 5: Create `_today_patient.html.erb` partial

**Files:**
- Create: `app/views/patients/_today_patient.html.erb`

- [ ] **Step 1: Create the partial**

```erb
<tr>
  <td data-label="<%= t :time %>">
    <span class="fw-medium"><%= appointment_time_with_duration(today_patient.starts_at, today_patient.ends_at) %></span>
  </td>
  <td data-label="<%= t :name %>">
    <div class="d-flex py-1 align-items-center">
      <%= link_to today_patient.patient, class: 'p-0 border-0 bg-transparent', style: 'line-height: 0;' do %>
        <%= avatar_for(today_patient.patient) %>
      <% end %>
      <div class="flex-fill">
        <div class="font-weight-medium"><%= today_patient.patient.fullname %></div>
      </div>
    </div>
  </td>
  <td class="text-muted" data-label="<%= t :uid %>">
    <%= today_patient.patient.uid %>
  </td>
  <td class="text-muted" data-label="<%= t :doctor %>">
    <%= today_patient.doctor.fullname %>
  </td>
  <td data-label="<%= t :status %>">
    <%= appointment_status_label(today_patient.status) %>
  </td>
  <td>
    <div class="btn-list flex-nowrap">
      <%= component :dropdown do %>
        <%= link_to t(:view_profile), today_patient.patient, class: "dropdown-item" %>
        <%= link_to t(:edit), edit_patient_path(today_patient.patient), class: "dropdown-item" %>
        <% unless today_patient.patient.missing_info? %>
          <%= link_to t(:create_new_payment), new_payment_path(patient_id: today_patient.patient.id), class: "dropdown-item" %>
        <% end %>
        <% if user_is_admin?(current_user) %>
          <%= link_to t(:delete), today_patient.patient, method: :delete, data: { confirm: t(:are_you_sure_no_undo) }, class: "dropdown-item text-red" %>
        <% end %>
      <% end %>
    </div>
  </td>
</tr>
```

- [ ] **Step 2: Commit**

```bash
git add app/views/patients/_today_patient.html.erb
git commit -m "feat(views): add today patient row partial"
```

---

### Task 6: Remove `updated_at` column from `_patient.html.erb`

**Files:**
- Modify: `app/views/patients/_patient.html.erb:26-28`

- [ ] **Step 1: Remove the `updated_at` cell**

Remove these lines (26-28) from `app/views/patients/_patient.html.erb`:

```erb
  <td class="text-muted" data-label="<%= t :updated_at %>">
    <%= time_ago_in_words patient.updated_at %>
  </td>
```

- [ ] **Step 2: Run existing tests to verify nothing breaks**

Run: `bin/rails test test/functional/patients_controller_test.rb`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add app/views/patients/_patient.html.erb
git commit -m "refactor(views): remove updated_at column from patient listing"
```

---

### Task 7: Rewrite `index.html.erb` with segment pills and conditional rendering

**Files:**
- Modify: `app/views/patients/index.html.erb`

- [ ] **Step 1: Rewrite the view**

Replace the full contents of `app/views/patients/index.html.erb`:

```erb
<div class="page-header mb-4">
  <div class="row align-items-center">
    <div class="col">
      <h2 class="page-title">
        <%= t :patients %>
      </h2>
    </div>
    <div class="col-auto ms-auto">
      <div class="btn-list">
        <%= link_to new_patient_url, class: "btn btn-primary d-sm-inline-block" do %>
          <svg xmlns="http://www.w3.org/2000/svg" class="icon" width="24" height="24" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" fill="none" stroke-linecap="round" stroke-linejoin="round"><path stroke="none" d="M0 0h24v24H0z" fill="none"></path><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line></svg>
          <%= t(:create_new_patient) %>
        <% end %>
      </div>
    </div>
  </div>
</div>

<% if @segment.present? %>
  <%= patients_segment_pills %>
<% end %>

<div class="page-body">
  <div class="card">
    <% if @segment == 'today' %>
      <% if @appointments.empty? %>
        <div class="card-body text-center py-5">
          <p class="text-muted mb-2"><%= t :patients_today_empty %></p>
          <%= link_to t(:patients_today_empty_hint), patients_url(segment: 'all'), class: "btn btn-outline-primary" %>
        </div>
      <% else %>
        <table class="table table-vcenter table-mobile-md card-table">
          <thead>
            <tr>
              <th><%= t :time %></th>
              <th><%= t :name %></th>
              <th><%= t :uid %></th>
              <th><%= t :doctor %></th>
              <th><%= t :status %></th>
              <th class="w-1"></th>
            </tr>
          </thead>
          <tbody>
            <%= render partial: 'today_patient', collection: @appointments, as: :today_patient %>
          </tbody>
        </table>
      <% end %>

    <% else %>
      <% if @patients.empty? %>
        <div class="card-body">
          <%= t :no_patients %>
        </div>
      <% else %>
        <table class="table table-vcenter table-mobile-md card-table">
          <thead>
            <tr>
              <th>
                <% if @segment == 'all' %>
                  <%= patients_sort_link(column: 'name', label_key: :name, letter: @current_letter) %>
                <% else %>
                  <%= t :name %>
                <% end %>
              </th>
              <th><%= t :uid %></th>
              <th>
                <%= t :status %>
                <%= help_tag t 'help.patients.status' %>
              </th>
              <th>
                <% if @segment == 'all' %>
                  <%= patients_sort_link(column: 'last_visit', label_key: :last_visit, letter: @current_letter) %>
                <% else %>
                  <%= t :last_visit %>
                <% end %>
              </th>
              <th class="w-1"></th>
            </tr>
          </thead>
          <tbody id="patients-list">
            <%= render partial: 'patient', collection: @patients, as: :patient %>
          </tbody>
        </table>
        <% if @segment == 'all' %>
          <div class="card-footer" id="patient-letter-pagination">
            <%= render partial: 'letter_pagination', locals: { letter: @current_letter, next_cursor: @next_cursor, sort_column: @sort_column, sort_direction: @sort_direction } %>
          </div>
        <% end %>
      <% end %>
    <% end %>
  </div>
</div>

<% if @segment == 'all' %>
  <ul class="pagination">
    <li class="page-item <%= @current_letter == '#' ? 'active' : '' %>">
      <%= link_to "#", patients_url(letter: '#', sort: @sort_column, direction: @sort_direction), class: "page-link" %>
    </li>
    <% letter_options.each do |letter| %>
      <li class="page-item <%= @current_letter == letter[:value] ? 'active' : '' %> <%= letter[:included?] ? '' : 'disabled' %>">
        <%= link_to letter[:value], patients_url(letter: letter[:value], sort: @sort_column, direction: @sort_direction), class: "page-link" %>
      </li>
    <% end %>
  </ul>

<% elsif @segment.nil? %>
  <span class="text-muted">
    <% if @patients.size == 0 %>
      <%= t :patient_search_results_zero, :patients_count => @patients.size %>
    <% elsif @patients.size == 1 %>
      <%= t :patient_search_results_one %>
    <% elsif @patients.size <= 20 %>
      <%= t :patient_search_results_few, :patients_count => @patients.size %>
    <% else %>
      <%= t :patient_search_results_many, :patients_count => @patients.size %>
    <% end %>
  </span>
<% end %>
```

- [ ] **Step 2: Run full test suite to verify**

Run: `bin/rails test test/functional/patients_controller_test.rb`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add app/views/patients/index.html.erb
git commit -m "feat(views): rewrite patient index with segment pills and today view"
```

---

### Task 8: Add timezone-sensitive test for Today segment

**Files:**
- Modify: `test/functional/patients_controller_test.rb`

- [ ] **Step 1: Write the timezone test**

Add to `test/functional/patients_controller_test.rb`:

```ruby
test 'today segment respects practice timezone' do
  practice = practices(:complete) # Europe/London
  doctor = doctors(:rebecca)
  datebook = datebooks(:playa_del_carmen)

  patient = Patient.create!(
    practice: practice, firstname: 'Timezone', lastname: 'Test',
    uid: 'TZ001', date_of_birth: Date.new(1990, 1, 1)
  )

  # Freeze time to 11 PM London time (March 21)
  # This is technically March 22 in UTC+0 at 23:00, still March 21 in London
  london_tz = ActiveSupport::TimeZone['Europe/London']
  frozen_time = london_tz.parse('2026-03-21 23:00:00')

  travel_to frozen_time do
    late_appt = Appointment.create!(
      datebook: datebook, doctor: doctor, patient: patient,
      starts_at: london_tz.parse('2026-03-21 22:00:00'),
      ends_at: london_tz.parse('2026-03-21 22:30:00'),
      status: Appointment.status[:confirmed]
    )

    get :index
    assert_response :success
    appointment_ids = assigns(:appointments).map(&:id)
    assert_includes appointment_ids, late_appt.id
  end
end
```

- [ ] **Step 2: Run test to verify it passes**

Run: `bin/rails test test/functional/patients_controller_test.rb -n "test_today_segment_respects_practice_timezone"`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add test/functional/patients_controller_test.rb
git commit -m "test(patients): add timezone-sensitive test for today segment"
```

---

### Task 9: Run full test suite and fix any regressions

**Files:**
- Possibly modify: any files with failing tests

- [ ] **Step 1: Run the full test suite**

Run: `bin/rails test`
Expected: All tests pass

- [ ] **Step 2: Fix any failures**

If any tests fail, fix them. Common issues:
- Existing tests that assume `GET /patients` returns letter-based results need `segment: 'all'` param
- Tests checking `@patients` on default index now need to check `@appointments`
- The `format.json` path may need adjustment if it relies on `@patients` being set in the Today segment

- [ ] **Step 3: Commit fixes if any**

```bash
git add -A
git commit -m "fix(tests): resolve regressions from patient listing redesign"
```

---

### Task 10: Manual smoke test checklist

- [ ] **Step 1: Verify Today segment**

Visit `/patients` — should show today's appointments (or empty state if none).

- [ ] **Step 2: Verify All patients segment**

Visit `/patients?segment=all` — should show alphabetical listing with A-Z picker, sort toggles, no `updated_at` column.

- [ ] **Step 3: Verify pills**

Both segments should show nav-pills. "Today" pill should have a count badge. Active pill should be highlighted.

- [ ] **Step 4: Verify search**

Search for a patient — pills should not appear. Results should render normally.

- [ ] **Step 5: Verify KPI link**

Click "New patients" KPI card on dashboard — should go to `?segment=new_this_week` and work as before, no pills.

- [ ] **Step 6: Verify cursor pagination on All patients**

Click a letter, scroll down, click "Load more patients" — should work with sort params preserved.

- [ ] **Step 7: Final commit if needed**

```bash
git commit -m "feat(patients): complete patient listing redesign v1"
```
