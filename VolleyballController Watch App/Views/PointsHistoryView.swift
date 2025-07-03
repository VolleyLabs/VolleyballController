import SwiftUI

struct PointsHistoryView: View {
    let points: [Point]
    let onClose: () -> Void
    let onDeletePoint: (Point) -> Void

    private var groupedPoints: [String: [Point]] {
        Dictionary(grouping: points) { point in
            guard let createdAt = point.createdAt else { return "Unknown" }
            let date = createdAt.prefix(10)
            return String(date)
        }
    }

    private var sortedDates: [String] {
        groupedPoints.keys.sorted(by: >)
    }

    var body: some View {
        NavigationView {
            listContent
                .navigationTitle("History")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            onClose()
                        }
                    }
                }
        }
    }

    private var listContent: some View {
        List {
            if points.isEmpty {
                emptyStateView
            } else {
                pointsSections
            }
        }
    }

    private var emptyStateView: some View {
        Text("No points recorded today")
            .foregroundColor(.secondary)
            .italic()
    }

    private var pointsSections: some View {
        ForEach(sortedDates, id: \.self) { date in
            pointSection(for: date)
        }
    }

    private func pointSection(for date: String) -> some View {
        Section(header: Text(formatDate(date))) {
            pointRows(for: date)
        }
    }

    private func pointRows(for date: String) -> some View {
        let datePoints = groupedPoints[date] ?? []
        let pointsWithScores = calculateRunningScores(for: datePoints)
        let reversedPoints = pointsWithScores.reversed()

        return ForEach(Array(reversedPoints.enumerated()), id: \.offset) { _, pointWithScore in
            PointRowView(point: pointWithScore.point, scoreString: pointWithScore.scoreString)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button("Delete", role: .destructive) {
                        onDeletePoint(pointWithScore.point)
                    }
                }
        }
    }

    private func calculateRunningScores(for points: [Point]) -> [(point: Point, scoreString: String)] {
        var leftScore = 0
        var rightScore = 0
        var result: [(point: Point, scoreString: String)] = []

        for point in points {
            // Add the point to the score
            if point.winner == .left {
                leftScore += 1
            } else {
                rightScore += 1
            }

            // Check if this completes a set (25+ with 2+ advantage)
            let isSetComplete = (leftScore >= 25 || rightScore >= 25) && abs(leftScore - rightScore) >= 2

            let scoreString = "\(leftScore)-\(rightScore)"
            result.append((point: point, scoreString: scoreString))

            // If set is complete, reset scores for next set
            if isSetComplete {
                leftScore = 0
                rightScore = 0
            }
        }

        return result
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        if let date = formatter.date(from: dateString) {
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }

        return dateString
    }
}

struct PointRowView: View {
    let point: Point
    let scoreString: String

    var body: some View {
        HStack {
            Text(scoreString)
                .font(.caption)
                .foregroundColor(.white)
                .frame(width: 40)

            if let type = point.type, type != .other {
                Text(type.emoji)
                    .font(.title3)
            }

            Spacer()

            if let createdAt = point.createdAt {
                Text(formatTime(createdAt))
                    .font(.caption2)
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(point.winner == .left ? Color.blue.opacity(0.7) : Color.red.opacity(0.7))
        .cornerRadius(8)
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
    }

    private func formatTime(_ dateString: String) -> String {
        // Try ISO8601 formatter first
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601Formatter.date(from: dateString) {
            return formatLocalTime(from: date)
        }

        // Try various DateFormatter patterns
        let dateFormatters = [
            "yyyy-MM-dd HH:mm:ss+00",
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'+00:00'"
        ]

        for pattern in dateFormatters {
            let formatter = DateFormatter()
            formatter.dateFormat = pattern
            formatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC

            if let date = formatter.date(from: dateString) {
                return formatLocalTime(from: date)
            }
        }

        // Fallback: try to extract time part manually and assume it's UTC
        if dateString.contains("T") {
            let timePart = String(dateString.split(separator: "T").last?.prefix(5) ?? "")
            // Try to parse as UTC time and convert to local
            let today = Calendar.current.dateInterval(of: .day, for: Date())?.start ?? Date()
            let year = Calendar.current.component(.year, from: today)
            let month = String(format: "%02d", Calendar.current.component(.month, from: today))
            let day = String(format: "%02d", Calendar.current.component(.day, from: today))
            let timeString = "\(year)-\(month)-\(day) \(timePart):00"

            let fallbackFormatter = DateFormatter()
            fallbackFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            fallbackFormatter.timeZone = TimeZone(secondsFromGMT: 0)

            if let date = fallbackFormatter.date(from: timeString) {
                return formatLocalTime(from: date)
            }

            return timePart
        }

        return dateString.suffix(5).description
    }

    private func formatLocalTime(from date: Date) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        timeFormatter.timeZone = TimeZone.current
        return timeFormatter.string(from: date)
    }
}

#Preview {
    PointsHistoryView(
        points: [
            Point(id: "1", createdAt: "2024-01-01T10:30:00Z", winner: .left, type: .ace, playerId: nil),
            Point(id: "2", createdAt: "2024-01-01T10:31:00Z", winner: .right, type: .attack, playerId: nil),
            Point(id: "3", createdAt: "2024-01-01T10:32:00Z", winner: .left, type: .block, playerId: nil)
        ],
        onClose: {},
        onDeletePoint: { _ in }
    )
}
