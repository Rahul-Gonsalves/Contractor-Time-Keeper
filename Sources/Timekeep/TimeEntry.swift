import Foundation

struct TimeEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var client: String     // canonical casing (see merge rules)
    var date: Date         // day precision; set automatically at creation
    var hours: Double      // 0.25 granularity encouraged, any positive value allowed
    var note: String       // optional, may be empty

    init(id: UUID = UUID(), client: String, date: Date, hours: Double, note: String) {
        self.id = id
        self.client = client
        self.date = date
        self.hours = hours
        self.note = note
    }
}
