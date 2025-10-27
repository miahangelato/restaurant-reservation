import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dateField", "timeSlotField", "numPeopleField"]

  connect() {
    console.log("Reservations controller connected")
    // Initialize visibility of progressive sections
    this.updateTimeSlotSection()
    this.updateTableSelection()
  }

  // Event handlers
  dateChanged() {
    this.updateAvailability()
  }

  timeSlotChanged() {
    console.log("Time slot changed")
    // When time slot changes, reload to get available tables
    const date = this.dateFieldTarget.value
    const numPeople = this.numPeopleFieldTarget.value
    const timeSlot = this.timeSlotFieldTarget.value
    
    console.log("Values:", { date, numPeople, timeSlot })
    
    if (date && numPeople && timeSlot) {
      console.log("Reloading page with time slot selection")
      const url = new URL(window.location)
      url.searchParams.set('date', date)
      url.searchParams.set('num_people', numPeople)
      url.searchParams.set('time_slot_id', timeSlot)
      
      window.location.href = url.toString()
    } else {
      console.log("Missing required fields, hiding table selection")
      this.hideTableSelection()
    }
  }

  numPeopleChanged() {
    this.updateAvailability()
  }

  tableSelected() {
    // Handle table selection if needed
    console.log("Table selected")
  }

  updateAvailability() {
    // Check if we have date and party size to show time slots
    const date = this.dateFieldTarget.value
    const numPeople = this.numPeopleFieldTarget.value
    
    if (date && numPeople) {
      // Reload the page with parameters to get updated availability
      const url = new URL(window.location)
      url.searchParams.set('date', date)
      url.searchParams.set('num_people', numPeople)
      
      // Clear time slot selection to force user to reselect
      url.searchParams.delete('time_slot_id')
      
      // Use Turbo to navigate to preserve form state
      window.location.href = url.toString()
    } else {
      this.hideTimeSlotSection()
      this.hideTableSelection()
    }
  }

  updateTimeSlotSection() {
    const date = this.dateFieldTarget.value
    const numPeople = this.numPeopleFieldTarget.value
    const timeSlotSection = document.getElementById('time-slot-section')
    
    if (date && numPeople && timeSlotSection) {
      timeSlotSection.style.display = 'block'
    } else {
      this.hideTimeSlotSection()
    }
  }

  updateTableSelection() {
    const timeSlot = this.timeSlotFieldTarget.value
    const tableSection = document.getElementById('table-selection-section')
    
    if (timeSlot && tableSection) {
      // Check if there are available tables in the DOM
      const hasAvailableTables = tableSection.querySelector('.table-option')
      if (hasAvailableTables) {
        tableSection.style.display = 'block'
        console.log("Showing table selection section")
      } else {
        this.hideTableSelection()
      }
    } else {
      this.hideTableSelection()
    }
  }

  hideTimeSlotSection() {
    const timeSlotSection = document.getElementById('time-slot-section')
    if (timeSlotSection) {
      timeSlotSection.style.display = 'none'
    }
  }

  hideTableSelection() {
    const tableSection = document.getElementById('table-selection-section')
    if (tableSection) {
      tableSection.classList.remove('show')
      tableSection.style.display = 'none'
    }
  }
}