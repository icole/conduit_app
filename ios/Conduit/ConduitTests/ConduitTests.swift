import Foundation
import UIKit
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

    @Test func notificationsOpenAsASheetSoTheyCloseWhenYouLeave() {
        #expect(configuration.properties(for: "/notifications").context == .modal)
        #expect(configuration.properties(for: "/notifications/5").context == .default)
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

@MainActor
struct BellComponentTests {
    @Test func saysHowManyThingsNeedYou() {
        #expect(BellComponent.label(title: "Notifications", count: 0) == "Notifications")
        #expect(BellComponent.label(title: "Notifications", count: 1) == "Notifications, 1 needs you")
        #expect(BellComponent.label(title: "Notifications", count: 4) == "Notifications, 4 need you")
    }

    @Test func badgesOnlyWhenSomethingNeedsYouUpTo99() {
        #expect(BellComponent.badgeNumber(0) == nil)
        #expect(BellComponent.badgeNumber(3) == 3)
        #expect(BellComponent.badgeNumber(250) == 99)
    }

    @Test func theBellSitsLeftOfThePagesButtonWhicheverArrivesFirst() {
        let item = UINavigationItem()
        let bell = UIBarButtonItem(title: "bell")
        let button = UIBarButtonItem(title: "add")
        item.setRightBarItem(bell, slot: .bell)
        item.setRightBarItem(button, slot: .button)
        #expect(item.rightBarButtonItems == [button, bell])

        let newBell = UIBarButtonItem(title: "bell 2")
        item.setRightBarItem(newBell, slot: .bell)
        #expect(item.rightBarButtonItems == [button, newBell])
    }
}

struct ChatUnavailableTests {
    @Test func explainsEachReasonTheServerGives() {
        #expect(StreamChatError.message(for: "community_not_active") == "Chat opens once your community is approved.")
        #expect(StreamChatError.message(for: "chat_disabled") == "Chat isn't turned on for your community.")
        #expect(StreamChatError.message(for: "email_unverified").hasPrefix("Verify your email address"))
        #expect(StreamChatError.message(for: nil) == "Chat couldn't load. Check your connection and try again.")
    }
}

@MainActor
struct UserAgentTests {
    // The web loads a bridge controller only when the user agent lists its component
    @Test func listsTheBridgeComponentsForTheWeb() {
        #expect(AppConfig.userAgent.contains("bridge-components: [button bell menu]"))
    }

    @Test func keepsWhatTheServerLooksFor() {
        #expect(AppConfig.userAgent.hasPrefix("Conduit iOS/2 (Turbo Native)"))
    }
}

struct ConduitLinkTabTests {
    // A notification opened from another tab goes to the tab it belongs to
    @Test func aLinkForAnotherTabSaysWhichTab() {
        #expect(ConduitLink.otherTab(for: "/tasks", from: "/meals") == .tasks)
        #expect(ConduitLink.otherTab(for: "/meals/5", from: "/") == .meals)
        #expect(ConduitLink.otherTab(for: "/calendar_events/3", from: "/tasks") == .home)
    }

    @Test func aLinkForThisTabStaysPut() {
        #expect(ConduitLink.otherTab(for: "/tasks", from: "/tasks") == nil)
        #expect(ConduitLink.otherTab(for: "/meals/5", from: "/meals") == nil)
    }
}
