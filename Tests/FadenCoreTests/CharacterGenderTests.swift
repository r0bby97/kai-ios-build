import XCTest
@testable import FadenCore

final class CharacterGenderTests: XCTestCase {
    private func card(_ tags: [String]) -> CharacterCard { .init(name: "Figur", tags: tags) }
    func testMaleAndFemaleUseWholeExplicitTagsWithoutSubstringCollisions() {
        for tag in ["Male", "Männlich", "MAENNLICH", "trans-male", "Trans Man"] {
            XCTAssertEqual(CharacterGenderFilter.classification(card([tag])), .male)
        }
        for tag in ["Female", "Weiblich", "trans_female", "Trans Woman"] {
            XCTAssertEqual(CharacterGenderFilter.classification(card([tag])), .female)
            XCTAssertFalse(CharacterGenderFilter.male.matches(card([tag])))
        }
    }
    func testDiverseMixedAndUnspecifiedCardsRemainInTheAdditionalCategory() {
        for tags in [[], ["Male", "Female"], ["Non-binary"], ["Nichtbinär"], ["Genderfluid", "Female"], ["Genderless"]] {
            XCTAssertEqual(CharacterGenderFilter.classification(card(tags)), .other)
        }
    }
    func testTheUsersPOVAndRoleplayTextDoNotDetermineTheCharactersGender() {
        var value = card(["FemalePOV", "male user", "AnyPOV"])
        value.name = "Mara"; value.description = "The user is a woman. A man waits outside."
        XCTAssertEqual(CharacterGenderFilter.classification(value), .other)
        value.tags.append("Male")
        XCTAssertEqual(CharacterGenderFilter.classification(value), .male)
    }
    func testGenderAndGenreCombineWithoutChangingEitherSelection() {
        let male = card(["Male", "Omegaverse"]), female = card(["Female", "Omegaverse"]), fantasy = card(["Male", "Fantasy"])
        let values = [male, female, fantasy].filter { CharacterGenderFilter.male.matches($0) && CharacterGenre.omegaverse.matches($0) }
        XCTAssertEqual(values, [male])
        XCTAssertTrue(CharacterGenderFilter.all.matches(female))
        XCTAssertTrue(CharacterGenderFilter.female.matches(card(["Weiblich", "Omegaverse"])), "Classification survives German tag translation")
    }
    func testCardexCombinesGenderWithGenreAndKeepsPopularityAndPagination() throws {
        let url = CardexCatalogueCodec.searchURL(query: "", position: .init(page: 2, cursor: "next"), includeAdult: true, genre: .omegaverse, gender: .male)
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let values = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(values["tags"], "omegaverse,male")
        XCTAssertEqual(values["sort"], "popular")
        XCTAssertEqual(values["cursor"], "next")
        XCTAssertNil(values["page"])
    }
    func testGenreTabsAreAlphabeticalInGermanWithAllFirst() {
        XCTAssertEqual(CharacterGenre.allCases.map(\.title), ["Alle", "Abenteuer", "Alltag", "BDSM", "Fantasy", "Guideverse", "Horror", "Mystery", "Noir", "Omegaverse", "Romantik", "Science-Fiction"])
        XCTAssertEqual(Set(CharacterGenre.allCases).count, 12)
    }
}
