import XCTest
@testable import OpenUsage

/// The one number→text place. `.tray` is the menu-bar form (shortest), `.row` the popover form
/// (abbreviated but money keeps cents), `.full` the exact tooltip/headline form. These cases pin the
/// behavior the old `WidgetData.format`, `MenuBarContent.compactValue`, and `formatTokens` each had.
final class MetricFormatterTests: XCTestCase {
    func testDollarsAbbreviateAboveAThousandPerStyle() {
        // Tray: whole dollars under $1k (decimals round away), abbreviated above.
        XCTAssertEqual(MetricFormatter.number(42, kind: .dollars, style: .tray), "$42")
        XCTAssertEqual(MetricFormatter.number(129.81, kind: .dollars, style: .tray), "$130")
        XCTAssertEqual(MetricFormatter.number(2059.07, kind: .dollars, style: .tray), "$2.1K")
        // Row: full cents under $1k, abbreviated with one decimal above (matching token counts).
        XCTAssertEqual(MetricFormatter.number(40.76, kind: .dollars, style: .row), "$40.76")
        XCTAssertEqual(MetricFormatter.number(2059.07, kind: .dollars, style: .row), "$2.1K")
        // Full: every digit, grouped.
        XCTAssertEqual(MetricFormatter.number(2059.07, kind: .dollars, style: .full), "$2,059.07")
    }

    func testCountsAbbreviateInTrayAndRowButKeepEveryDigitInFull() {
        XCTAssertEqual(MetricFormatter.number(56_904_995, kind: .count, style: .tray), "56.9M")
        XCTAssertEqual(MetricFormatter.number(56_904_995, kind: .count, style: .row), "56.9M")
        XCTAssertEqual(MetricFormatter.number(56_904_995, kind: .count, style: .full), "56,904,995")
        XCTAssertEqual(MetricFormatter.number(1_485_201_513, kind: .count, style: .row), "1.5B")
        // Below 1,000, up to one decimal survives (a fractional credit balance).
        XCTAssertEqual(MetricFormatter.number(820.6, kind: .count, style: .row), "820.6")
    }

    func testBalancePinsUseCompactCurrencySymbolsAndKeepCents() {
        let cases: [(Double, String, String)] = [
            (7.17, "7.17", "$7.17"), (0.42, "0.42", "$0.42"), (0, "0.00", "$0.00"),
            (-0.01, "-0.01", "-$0.01"), (2059.07, "2.1K", "$2.1K")
        ]
        for (amount, expected, expectedUSD) in cases {
            let cny = MetricValue(number: amount, kind: .dollars, currencyCode: "CNY")
            let usd = MetricValue(number: amount, kind: .dollars, currencyCode: "USD")
            XCTAssertEqual(MetricFormatter.string(for: cny, style: .tray, keepingCents: true), "¥" + expected)
            XCTAssertEqual(MetricFormatter.string(for: usd, style: .tray, keepingCents: true), expectedUSD)
            XCTAssertEqual(MetricFormatter.string(for: cny, style: .row), "CNY " + expected)
        }
        let balance = MetricValue(number: 7.17, kind: .dollars, currencyCode: "CNY")
        XCTAssertEqual(MetricFormatter.string(for: balance, style: .full), "CNY 7.17")
    }

    func testPercentRoundsToWholeInEveryStyle() {
        XCTAssertEqual(MetricFormatter.number(95, kind: .percent, style: .full), "95%")
        XCTAssertEqual(MetricFormatter.number(95.4, kind: .percent, style: .tray), "95%")
    }

    func testTruncatedTrayValuesDropDecimalsTowardZero() {
        let cases: [(Double, String)] = [
            (7.99, "7"), (-7.99, "-7"), (0.99, "0"), (-0.99, "0"),
            (999.99, "999"), (1999.99, "1K"), (-1999.99, "-1K"),
            (1_999_999, "1M")
        ]
        for (amount, expected) in cases {
            for (currency, prefix) in [("CNY", "¥"), ("USD", "$"), ("EUR", "EUR ")] {
                let value = MetricValue(number: amount, kind: .dollars, currencyCode: currency)
                XCTAssertEqual(MetricFormatter.string(for: value, style: .tray, keepingCents: true, truncatingDecimals: true), prefix + expected)
            }
            XCTAssertEqual(MetricFormatter.number(amount, kind: .count, style: .tray, truncatingDecimals: true), expected)
        }
        let value = MetricValue(number: 7.99, kind: .dollars, currencyCode: "CNY")
        XCTAssertEqual(MetricFormatter.string(for: value, style: .row, truncatingDecimals: true), "CNY 7.99")
        XCTAssertEqual(MetricFormatter.number(42.9, kind: .percent, style: .tray, truncatingDecimals: true), "43%")
    }

    func testPercentClampsOutOfRangeSamples() {
        // Percent is a bounded 0...100 domain: a bad sample (a provider reporting a negative or >100
        // utilization) must never print "-5%" or "130%" — it clamps to the nearest bound. (#703)
        XCTAssertEqual(MetricFormatter.number(-5, kind: .percent, style: .full), "0%")
        XCTAssertEqual(MetricFormatter.number(-5, kind: .percent, style: .tray), "0%")
        XCTAssertEqual(MetricFormatter.number(130, kind: .percent, style: .full), "100%")
        XCTAssertEqual(MetricFormatter.number(100.6, kind: .percent, style: .row), "100%")
    }

    func testValueStringAppendsUnitLabelWhenPresent() {
        let credits = MetricValue(number: 772, kind: .count, label: "credits")
        XCTAssertEqual(MetricFormatter.string(for: credits, style: .row), "772 credits")
        XCTAssertEqual(MetricFormatter.string(for: credits, style: .full), "772 credits")
        // Tokens carry no label, so nothing is appended in any style.
        let tokens = MetricValue(number: 56_904_995, kind: .count)
        XCTAssertEqual(MetricFormatter.string(for: tokens, style: .row), "56.9M")
        XCTAssertEqual(MetricFormatter.string(for: tokens, style: .full), "56,904,995")
    }

    func testCostPerMtokAppendsUnitToDollarFormatting() {
        XCTAssertEqual(MetricFormatter.costPerMtok(32, style: .tray), "$32/MTok")
        XCTAssertEqual(MetricFormatter.costPerMtok(32.1, style: .row), "$32.10/MTok")
        XCTAssertEqual(MetricFormatter.costPerMtok(32.1, style: .full), "$32.10/MTok")
        XCTAssertEqual(MetricFormatter.costPerMtok(2059.07, style: .tray), "$2.1K/MTok")
        XCTAssertEqual(MetricFormatter.costPerMtok(2059.07, style: .full), "$2,059.07/MTok")
    }

    func testTotalSpendRingCenterSplitsValueAndUnit() {
        let cases: [(value: Double, metric: TotalSpendMetric, primary: String, unit: String)] = [
            (533, .cost, "$533", "dollars"),
            (2059.07, .cost, "$2.1K", "dollars"),
            (12_400_000, .tokens, "12.4", "million"),
            (1_500_000_000, .tokens, "1.5", "billion"),
            (820.6, .tokens, "820.6", "tokens"),
            (1.37, .costPerMtok, "$1.37", "MTok")
        ]

        for testCase in cases {
            XCTAssertEqual(
                MetricFormatter.totalSpendRingCenter(testCase.value, metric: testCase.metric),
                .init(primary: testCase.primary, unit: testCase.unit)
            )
        }
    }
}
