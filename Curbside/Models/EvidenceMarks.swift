import Foundation


/// Where each change's evidence sits in the transcript, numbered like its row (1-based), in reading order.
/// Spans the model didn't quote verbatim, and spans overlapping an earlier one, go unmarked.
func evidenceMarks(in transcript: String, evidence: [String]) -> [(range: Range<String.Index>, number: Int)] {
    let found = evidence.enumerated().compactMap { index, span -> (range: Range<String.Index>, number: Int)? in
        let span = span.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        guard !span.isEmpty, let range = transcript.range(of: span, options: .caseInsensitive) else { return nil }
        return (range, index + 1)
    }
    var end = transcript.startIndex
    return found.sorted { $0.range.lowerBound < $1.range.lowerBound }.filter { mark in
        guard mark.range.lowerBound >= end else { return false }
        end = mark.range.upperBound
        return true
    }
}
