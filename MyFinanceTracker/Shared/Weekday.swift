import Foundation

enum Weekday {
    /// Monday–Sunday, in the order this app uses everywhere.
    static let allNames = [
        "Monday", "Tuesday", "Wednesday", "Thursday",
        "Friday", "Saturday", "Sunday"
    ]

    /// Today's weekday name (e.g. "Wednesday"), used to default day pickers.
    static var today: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date())
    }
}
