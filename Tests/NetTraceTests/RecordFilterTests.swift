import Foundation
import Testing
@testable import NetTrace

@Suite("Search and filters")
struct RecordFilterTests {
    let records: [NetworkRecord] = [
        NetworkRecord(method: "GET", url: URL(string: "https://api.example.com/v2/products?category=shoes")!, endDate: Date(), statusCode: 200),
        NetworkRecord(method: "POST", url: URL(string: "https://api.example.com/v2/cart/items")!, endDate: Date(), statusCode: 201),
        NetworkRecord(method: "GET", url: URL(string: "https://api.example.com/v2/promotions/summer")!, endDate: Date(), statusCode: 404),
        NetworkRecord(method: "POST", url: URL(string: "https://api.example.com/v2/checkout")!, endDate: Date(), statusCode: 500),
        NetworkRecord(method: "delete", url: URL(string: "https://cdn.example.com/cache/31")!, endDate: Date(), errorDescription: "The request timed out."),
        NetworkRecord(method: "GET", url: URL(string: "https://api.example.com/v2/orders")!),
    ]

    @Test func emptyFilterKeepsEverythingInOrder() {
        let filter = RecordFilter()
        #expect(!filter.isActive)
        #expect(filter.apply(to: records) == records)
    }

    @Test func searchMatchesURLMethodStatusAndError() {
        #expect(RecordFilter(searchText: "cart").apply(to: records).map(\.statusCode) == [201])
        #expect(RecordFilter(searchText: "404").apply(to: records).count == 1)
        #expect(RecordFilter(searchText: "TIMED out").apply(to: records).map(\.method) == ["DELETE"])
        #expect(RecordFilter(searchText: "post").apply(to: records).count == 2)
        #expect(RecordFilter(searchText: "   ").apply(to: records).count == records.count)
    }

    @Test func everyTermMustMatch() {
        #expect(RecordFilter(searchText: "post checkout").apply(to: records).map(\.statusCode) == [500])
        #expect(RecordFilter(searchText: "post shoes").apply(to: records).isEmpty)
    }

    @Test func methodFilterIsCaseInsensitive() {
        let filter = RecordFilter(methods: ["post", "Delete"])
        #expect(filter.apply(to: records).map(\.method) == ["POST", "POST", "DELETE"])
    }

    @Test func categoryFilter() {
        let failures = RecordFilter(categories: [.clientError, .serverError, .failed]).apply(to: records)
        #expect(failures.map(\.statusCode) == [404, 500, nil])
        let pending = RecordFilter(categories: [.pending]).apply(to: records)
        #expect(pending.count == 1)
    }

    @Test func filtersCombine() {
        let filter = RecordFilter(searchText: "v2", methods: ["GET"], categories: [.success])
        #expect(filter.apply(to: records).count == 1)
    }

    @Test func togglingAddsAndRemoves() {
        var filter = RecordFilter()
        filter.toggle(method: "get")
        #expect(filter.methods == ["GET"])
        filter.toggle(method: "GET")
        #expect(filter.methods.isEmpty)
        filter.toggle(category: .serverError)
        #expect(filter.categories == [.serverError])
        #expect(filter.isActive)
        filter.toggle(category: .serverError)
        #expect(!filter.isActive)
    }

    @Test func availableMethodsPutCommonOnesFirst() {
        let extra = records + [NetworkRecord(method: "PROPFIND", url: URL(string: "https://dav.example.com")!)]
        #expect(RecordFilter.methods(in: extra) == ["GET", "POST", "DELETE", "PROPFIND"])
    }
}
