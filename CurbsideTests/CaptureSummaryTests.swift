import Foundation
import Testing
@testable import Curbside

private func op(_ kind: CaptureOp.Kind, in ref: String = CaptureFixtures.blue, target: String? = nil, _ fields: [String: Patch.Value] = [:]) -> CaptureOp {
    CaptureOp(op: kind, householdRef: ref, targetID: target, fields: fields, evidence: "x", confidence: 0.9, needsReview: false, checked: true)
}

private func summary(_ op: CaptureOp) -> CaptureSummary {
    CaptureSummary(op, households: CaptureFixtures.households, newLabels: ["new:1": "Gray house"])
}

@Suite struct CaptureSummaryTests {
    @Test func everyKindReads() {
        let theo = "01JCAPTVRE00000000000000P2"
        let biscuit = "01JCAPTVRE00000000000000X1"
        let cases: [(CaptureOp, String, String)] = [
            (op(.createHousehold, in: "new:1", ["label": .string("Gray house"), "address": .string("30 Maple Ct")]), "GRAY HOUSE · NEW HOUSE", "Gray house, 30 Maple Ct"),
            (op(.updateHousehold, ["address": .string("24 Maple Ct")]), "BLUE HOUSE", "Address: 24 Maple Ct"),
            (op(.addPerson, in: "new:1", ["name": .string("Ollie"), "role": .string("kid"), "birth_year": .int(2020), "birth_year_approx": .bool(true)]), "GRAY HOUSE · NEW PERSON", "Ollie, kid, born ~2020"),
            (op(.updatePerson, target: theo, ["birthday": .string("03-03")]), "BLUE HOUSE · THEO", "Birthday 03-03"),
            (op(.updatePerson, target: theo, ["birth_year": .int(2018)]), "BLUE HOUSE · THEO", "Born 2018"),
            (op(.addPet, ["name": .string("Pickles"), "species": .string("beagle")]), "BLUE HOUSE · NEW PET", "Pickles, beagle"),
            (op(.updatePet, target: biscuit, ["species": .string("beagle")]), "BLUE HOUSE · BISCUIT", "Species: beagle"),
            (op(.addNote, ["text": .string("Block party next Saturday")]), "BLUE HOUSE · NOTE", "Block party next Saturday"),
            (op(.touchLastTalked), "BLUE HOUSE", "Talked today"),
        ]
        for (op, who, change) in cases {
            let summary = summary(op)
            #expect(summary.who == who)
            #expect(summary.change == change)
        }
    }

    @Test func numberComesFromTheAddress() {
        #expect(summary(op(.touchLastTalked)).number == "14")
        #expect(summary(op(.addNote, in: "new:1")).number == nil)
    }

    @Test func clearedFieldSaysSo() {
        #expect(summary(op(.updatePet, target: "01JCAPTVRE00000000000000X1", ["notes": .null])).change == "Notes: cleared")
    }
}

@Suite struct EvidenceMarksTests {
    private let said = "Ran into Clementine. Odo just turned five and starts kindergarten in the fall."

    private func marked(_ evidence: [String]) -> [String] {
        evidenceMarks(in: said, evidence: evidence).map { "\($0.number):\(said[$0.range])" }
    }

    @Test func marksInReadingOrderWithRowNumbers() {
        #expect(marked(["starts kindergarten in the fall", "Ran into Clementine."]) == ["2:Ran into Clementine", "1:starts kindergarten in the fall"])
    }

    @Test func paraphraseAndOverlapGoUnmarked() {
        #expect(marked(["Odo just turned five", "turned five and starts", "Odo is five now"]) == ["1:Odo just turned five"])
    }

    @Test func caseDoesNotMatter() {
        #expect(marked(["odo JUST turned five"]) == ["1:Odo just turned five"])
    }
}
