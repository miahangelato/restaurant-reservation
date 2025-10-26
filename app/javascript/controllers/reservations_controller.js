import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dateField", "timeSlotField", "numPeopleField", "tableSelection"]

  connect() {
    this.updateTableSelection()
  }

  updateTableSelection() {
    const date = this.dateFieldTarget.value
    const timeSlotId = this.timeSlotFieldTarget.value
    const numPeople = this.numPeopleFieldTarget.value

    if (date && timeSlotId && numPeople) {
      this.loadAvailableTables(date, timeSlotId, numPeople)
    } else {
      this.showTableSelectionPlaceholder()
    }
  }

  async loadAvailableTables(date, timeSlotId, numPeople) {
    try {
      const response = await fetch(`/reservations/available_tables?date=${date}&time_slot_id=${timeSlotId}&num_people=${numPeople}`)
      const html = await response.text()
      this.tableSelectionTarget.innerHTML = html
    } catch (error) {
      console.error('Error loading available tables:', error)
      this.showTableSelectionPlaceholder()
    }
  }

  showTableSelectionPlaceholder() {
    this.tableSelectionTarget.innerHTML = `
      <div class="table-selection-placeholder">
        <p class="text-muted">💡 Select a date and time above to see available tables</p>
      </div>
    `
  }

  // Event handlers
  dateChanged() {
    this.clearTableSelection()
    this.updateTableSelection()
  }

  timeSlotChanged() {
    this.clearTableSelection()
    this.updateTableSelection()
  }

  numPeopleChanged() {
    this.clearTableSelection()
    this.updateTableSelection()
  }

  clearTableSelection() {
    // Clear any selected table when form inputs change
    const selectedRadio = this.element.querySelector('input[name="reservation[table_id]"]:checked')
    if (selectedRadio) {
      selectedRadio.checked = false
    }
  }
}