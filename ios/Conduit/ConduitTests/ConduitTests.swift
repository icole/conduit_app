import Foundation
import Testing
import HotwireNative
@testable import Conduit

@MainActor
struct PathConfigurationTests {
    let configuration = PathConfiguration(sources: [
        .file(Bundle.main.url(forResource: "path-configuration", withExtension: "json")!)
    ])

    @Test func formsOpenAsSheetsEvenWithAQueryString() {
        #expect(configuration.properties(for: "/tasks/new").context == .modal)
        #expect(configuration.properties(for: "/tasks/new?return_to=%2Ftasks").context == .modal)
        #expect(configuration.properties(for: "/meals/4/edit?return_to=%2Fmeals").context == .modal)
    }

    @Test func documentEditorsOpenFullScreen() {
        #expect(configuration.properties(for: "/documents/7/edit").context == .default)
        #expect(configuration.properties(for: "/documents/7/edit?return_to=%2Fdocuments").context == .default)
    }

    @Test func savingASheetFormRefreshesTheScreenBeneath() {
        #expect(configuration.properties(for: "/refresh_historical_location").presentation == .refresh)
    }
}

@MainActor
struct ButtonComponentTests {
    @Test func theWebsImagesBecomeSymbols() {
        #expect(ButtonComponent.symbolName(for: "plus") == "plus")
        #expect(ButtonComponent.symbolName(for: "more") == "ellipsis.circle")
        #expect(ButtonComponent.symbolName(for: nil) == nil)
        #expect(ButtonComponent.symbolName(for: "sparkles") == nil)
    }
}
