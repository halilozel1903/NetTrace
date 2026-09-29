import Foundation
import NetTrace

/// Fixed, realistic traffic of a small shop app. Used for the screenshots and the
/// "Add sample requests" button, so the inspector can be explored without a network.
enum SampleData {
    /// 29 Sep 2026, 09:41:00 UTC.
    static let start = Date(timeIntervalSince1970: 1_790_674_860)

    /// A store with every sample request, newest first.
    static func makeStore() -> NetTraceStore {
        NetTraceStore(records: Array(makeRecords(stableIDs: true).reversed()))
    }

    /// The JSON product request shown in the `detail` screenshot.
    static var productDetail: NetworkRecord {
        makeRecords(stableIDs: true).first { $0.url.path() == "/v2/products/8841" }!
    }

    /// The sample requests in the order they were made.
    static func makeRecords(stableIDs: Bool) -> [NetworkRecord] {
        var number = 0
        func record(
            _ method: String,
            _ url: String,
            at offset: TimeInterval,
            took duration: TimeInterval?,
            status: Int? = nil,
            requestHeaders: [String: String] = [:],
            requestBody: String? = nil,
            responseHeaders: [String: String] = [:],
            responseBody: String? = nil,
            responseSize: Int? = nil,
            error: String? = nil
        ) -> NetworkRecord {
            number += 1
            let id = stableIDs
                ? UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", number))!
                : UUID()
            let began = start.addingTimeInterval(offset)
            return NetworkRecord(
                id: id,
                method: method,
                url: URL(string: url)!,
                requestHeaders: baseRequestHeaders.merging(requestHeaders) { $1 },
                requestBody: requestBody.map { Data($0.utf8) },
                startDate: began,
                endDate: duration.map { began.addingTimeInterval($0) },
                statusCode: status,
                responseHeaders: status == nil ? [:] : baseResponseHeaders.merging(responseHeaders) { $1 },
                responseBody: responseBody.map { Data($0.utf8) },
                responseBodySize: responseSize ?? responseBody?.utf8.count,
                errorDescription: error
            )
        }

        return [
            record("GET", "https://api.example.com/v2/config", at: 0, took: 0.064, status: 200,
                   responseBody: #"{"minimumVersion":"3.2.0","features":{"applePay":true,"liveChat":false},"supportEmail":"help@example.com"}"#),
            record("POST", "https://auth.example.com/oauth/token", at: 1.2, took: 0.318, status: 200,
                   requestHeaders: ["Content-Type": "application/x-www-form-urlencoded"],
                   requestBody: "grant_type=refresh_token&client_id=shop-ios",
                   responseBody: #"{"token_type":"Bearer","expires_in":3600,"scope":"catalog cart orders"}"#),
            record("GET", "https://api.example.com/v2/users/me", at: 2.0, took: 0.142, status: 200,
                   requestHeaders: ["Authorization": Redactor.placeholder],
                   responseBody: #"{"id":"u_5f2a","name":"Ada Park","email":"ada@example.com","tier":"gold","addresses":2}"#),
            record("GET", "https://api.example.com/v2/products?category=shoes&page=1", at: 2.5, took: 0.186, status: 200,
                   responseBody: productList, responseSize: 18_841),
            record("GET", "https://cdn.example.com/images/8841/hero.jpg", at: 2.9, took: 0.534, status: 200,
                   requestHeaders: ["Accept": "image/*"],
                   responseHeaders: ["Content-Type": "image/jpeg", "Cache-Control": "public, max-age=31536000"],
                   responseSize: 412_870),
            record("GET", "https://api.example.com/v2/products/8841", at: 4.1, took: 0.088, status: 200,
                   responseHeaders: ["ETag": #"W/"8841-1a9f""#, "X-Cache": "MISS"],
                   responseBody: productJSON),
            record("GET", "https://api.example.com/v2/promotions/summer-sale", at: 5.0, took: 0.071, status: 404,
                   responseBody: #"{"error":"not_found","message":"No promotion named summer-sale.","status":404}"#),
            record("POST", "https://api.example.com/v2/cart/items", at: 6.3, took: 0.211, status: 201,
                   requestHeaders: ["Content-Type": "application/json"],
                   requestBody: #"{"productId":8841,"size":42,"color":"Moss","quantity":1}"#,
                   responseBody: #"{"cartId":"c_77","items":3,"subtotal":{"amount":287.00,"currency":"EUR"}}"#),
            record("GET", "https://analytics.example.com/v1/flags", at: 6.4, took: 0.049, status: 304),
            record("PATCH", "https://api.example.com/v2/users/me/preferences", at: 7.8, took: 0.167, status: 200,
                   requestHeaders: ["Content-Type": "application/json"],
                   requestBody: #"{"newsletter":false,"sizeSystem":"EU"}"#,
                   responseBody: #"{"newsletter":false,"sizeSystem":"EU","updatedAt":"2026-09-29T09:41:07Z"}"#),
            record("POST", "https://api.example.com/v2/checkout", at: 9.2, took: 1.284, status: 500,
                   requestHeaders: ["Content-Type": "application/json", "Idempotency-Key": "9b1c7e02"],
                   requestBody: #"{"cartId":"c_77","payment":"apple_pay","shippingAddress":1}"#,
                   responseBody: #"{"error":"internal","message":"Payment service unavailable.","traceId":"c1f04e9a"}"#),
            record("DELETE", "https://api.example.com/v2/cart/items/31", at: 10.0, took: 0.096, status: 204),
            record("GET", "https://api.example.com/v2/recommendations?limit=12", at: 11.5, took: 10.0,
                   error: "The request timed out."),
            record("GET", "https://api.example.com/v2/orders?status=open", at: 12.4, took: nil),
        ]
    }

    private static let baseRequestHeaders: [String: String] = [
        "Accept": "application/json",
        "Accept-Language": "en-GB;q=1.0",
        "User-Agent": "Shop/3.4 (iPhone; iOS 26.0)",
    ]

    private static let baseResponseHeaders: [String: String] = [
        "Content-Type": "application/json; charset=utf-8",
        "Date": "Tue, 29 Sep 2026 09:41:04 GMT",
        "Server": "nginx",
        "Cache-Control": "private, max-age=60",
        "Vary": "Accept-Encoding",
        "X-Request-Id": "req_8Hq2Zt41",
        "Set-Cookie": Redactor.placeholder,
    ]

    private static let productJSON = #"""
    {"id":8841,"name":"Trail Runner 2","brand":"Northpeak","price":{"amount":129.00,"currency":"EUR","discount":null},"inStock":true,"rating":4.7,"reviewCount":1284,"colors":["Moss","Slate","Ember"],"sizes":[40,41,42,43,44,45],"images":[{"url":"https://cdn.example.com/images/8841/hero.jpg","width":1600,"height":1200}],"shipping":{"freeOver":50,"estimatedDays":2,"express":true},"tags":["running","trail","waterproof"],"updatedAt":"2026-09-28T17:04:11Z"}
    """#

    private static let productList = #"""
    {"page":1,"pageSize":20,"total":64,"items":[{"id":8841,"name":"Trail Runner 2","price":129.00},{"id":8790,"name":"City Knit","price":89.00},{"id":8702,"name":"Summit GTX","price":179.00}]}
    """#
}
