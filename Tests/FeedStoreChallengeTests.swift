//
//  Copyright © 2019 Essential Developer. All rights reserved.
//

import XCTest
import FeedStoreChallenge

import RealmSwift

extension Array where Element == LocalFeedImage {

	func toRealmList() -> List<RealmFeedImage> {
		let list = List<RealmFeedImage> ()
		forEach { list.append(.init($0)) }
		return list
	}
}

extension List where Element == RealmFeedImage {

	func toArray() -> [LocalFeedImage] {
		var array = [LocalFeedImage]()
		for item in self {
			guard let local = item.local else { continue }
			array.append(local)
		}
		return array
	}
}

@objcMembers
class Cache: Object {
	dynamic var realmFeed = List<RealmFeedImage>()
	dynamic var timestamp = Date()
	
	var feed: [LocalFeedImage] {
		realmFeed.toArray()
	}
	
	convenience init(realmFeed: List<RealmFeedImage>, timestamp: Date) {
		self.init()
		self.realmFeed = realmFeed
		self.timestamp = timestamp
	}
}

@objcMembers
class RealmFeedImage: Object {
	dynamic var uuidString: String = ""
	dynamic var mDescription: String?
	dynamic var location: String?
	dynamic var urlString: String = ""
	
	var id: UUID? {
		UUID(uuidString: uuidString)
	}
	
	var url: URL? {
		URL(string: urlString)
	}
	
	var local: LocalFeedImage? {
		guard let id = id, let url = url else { return nil }
		return LocalFeedImage(id: id, description: mDescription, location: location, url: url)
	}
	
	convenience init(_ image: LocalFeedImage) {
		self.init()
		uuidString = image.id.uuidString
		mDescription = image.description
		location = image.location
		urlString = image.url.absoluteString
	}
}


class RealmFeedStore: FeedStore {
	
	let storeURL: URL?
	
	init(storeURL: URL?) {
		self.storeURL = storeURL
	}
	
	func retrieve(completion: @escaping RetrievalCompletion) {
		do {
			let realm = try getRealm()
			if let cache = realm.objects(Cache.self).last {
				completion(.found(feed: cache.feed, timestamp: cache.timestamp))
			} else {
				completion(.empty)
			}
		}catch Realm.Error.fileNotFound, Realm.Error.filePermissionDenied {
			completion(.empty)
		} catch {
			completion(.failure(error))
		}
	}
	
	func insert(_ feed: [LocalFeedImage], timestamp: Date, completion: @escaping InsertionCompletion) {
		do {
			let realm = try getRealm()
			try realm.write {
				realm.add(Cache(realmFeed: feed.toRealmList(), timestamp: timestamp))
			}
			completion(nil)
		} catch {
			completion(error)
		}
	}
	
	func deleteCachedFeed(completion: @escaping DeletionCompletion) {
		let realm = try! getRealm()
		try! realm.write {
			realm.deleteAll()
		}
		completion(nil)
	}
	
	private func getRealm() throws -> Realm {
		if let storeURL = storeURL {
			var config = Realm.Configuration.defaultConfiguration
			config.fileURL = storeURL
			return try Realm(configuration: config)
		} else {
			return try Realm()
		}
	}
}

class FeedStoreChallengeTests: XCTestCase, FeedStoreSpecs {
	
	//  ***********************
	//
	//  Follow the TDD process:
	//
	//  1. Uncomment and run one test at a time (run tests with CMD+U).
	//  2. Do the minimum to make the test pass and commit.
	//  3. Refactor if needed and commit again.
	//
	//  Repeat this process until all tests are passing.
	//
	//  ***********************
	
	override func setUp() {
		super.setUp()
		
		setupEmptyStoreState()
	}
	
	override func tearDown() {
		super.tearDown()
		
		undoStoreSideEffects()
	}
	
	func test_retrieve_deliversEmptyOnEmptyCache() throws {
		let sut = try makeSUT()
		
		assertThatRetrieveDeliversEmptyOnEmptyCache(on: sut)
	}
	
	func test_retrieve_hasNoSideEffectsOnEmptyCache() throws {
		let sut = try makeSUT()

		assertThatRetrieveHasNoSideEffectsOnEmptyCache(on: sut)
	}
	
	func test_retrieve_deliversFoundValuesOnNonEmptyCache() throws {
		let sut = try makeSUT()

		assertThatRetrieveDeliversFoundValuesOnNonEmptyCache(on: sut)
	}
	
	func test_retrieve_hasNoSideEffectsOnNonEmptyCache() throws {
		let sut = try makeSUT()

		assertThatRetrieveHasNoSideEffectsOnNonEmptyCache(on: sut)
	}
	
	func test_insert_deliversNoErrorOnEmptyCache() throws {
		let sut = try makeSUT()

		assertThatInsertDeliversNoErrorOnEmptyCache(on: sut)
	}
	
	func test_insert_deliversNoErrorOnNonEmptyCache() throws {
		let sut = try makeSUT()

		assertThatInsertDeliversNoErrorOnNonEmptyCache(on: sut)
	}
	
	func test_insert_overridesPreviouslyInsertedCacheValues() throws {
		let sut = try makeSUT()

		assertThatInsertOverridesPreviouslyInsertedCacheValues(on: sut)
	}
	
	func test_delete_deliversNoErrorOnEmptyCache() throws {
		let sut = try makeSUT()

		assertThatDeleteDeliversNoErrorOnEmptyCache(on: sut)
	}
	
	func test_delete_hasNoSideEffectsOnEmptyCache() throws {
		let sut = try makeSUT()

		assertThatDeleteHasNoSideEffectsOnEmptyCache(on: sut)
	}
	
	func test_delete_deliversNoErrorOnNonEmptyCache() throws {
		let sut = try makeSUT()

		assertThatDeleteDeliversNoErrorOnNonEmptyCache(on: sut)
	}
	
	func test_delete_emptiesPreviouslyInsertedCache() throws {
		let sut = try makeSUT()

		assertThatDeleteEmptiesPreviouslyInsertedCache(on: sut)
	}
	
	func test_storeSideEffects_runSerially() throws {
		let sut = try makeSUT()

		assertThatSideEffectsRunSerially(on: sut)
	}
	
	// - MARK: Helpers
	
	private func makeSUT(url: URL? = nil) throws -> FeedStore {
		let store = RealmFeedStore(storeURL: url ?? testSpecificStoreURL())
		return store
	}
	
	private func deleteStoreArtifacts() {
		try? FileManager.default.removeItem(at: testSpecificStoreURL())
	}
	
	private func setupEmptyStoreState() {
		deleteStoreArtifacts()
	}
	
	private func undoStoreSideEffects() {
		deleteStoreArtifacts()
	}
	
	private func testSpecificStoreURL() -> URL {
		cachesDirectory().appendingPathComponent("\(type(of: self)).realm")
	}
	
	private func cachesDirectory() -> URL {
		FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
	}
}

//  ***********************
//
//  Uncomment the following tests if your implementation has failable operations.
//
//  Otherwise, delete the commented out code!
//
//  ***********************

extension FeedStoreChallengeTests: FailableRetrieveFeedStoreSpecs {

	func test_retrieve_deliversFailureOnRetrievalError() throws {
		let url = testSpecificStoreURL()
		let sut = try makeSUT(url: url)
		
		try "invalidData".write(to: url, atomically: true, encoding: .utf8)

		assertThatRetrieveDeliversFailureOnRetrievalError(on: sut)
	}

	func test_retrieve_hasNoSideEffectsOnFailure() throws {
		let url = testSpecificStoreURL()
		let sut = try makeSUT(url: url)
		
		try "invalidData".write(to: url, atomically: true, encoding: .utf8)

		assertThatRetrieveDeliversFailureOnRetrievalError(on: sut)
	}
}

extension FeedStoreChallengeTests: FailableInsertFeedStoreSpecs {

	func test_insert_deliversErrorOnInsertionError() throws {
		let invalidStoreURL = URL(string: "invalid://store-url")!
		let sut = try makeSUT(url: invalidStoreURL)

		assertThatInsertDeliversErrorOnInsertionError(on: sut)
	}

	func test_insert_hasNoSideEffectsOnInsertionError() throws {
//		let sut = try makeSUT()
//
//		assertThatInsertHasNoSideEffectsOnInsertionError(on: sut)
	}

}

//extension FeedStoreChallengeTests: FailableDeleteFeedStoreSpecs {
//
//	func test_delete_deliversErrorOnDeletionError() throws {
////		let sut = try makeSUT()
////
////		assertThatDeleteDeliversErrorOnDeletionError(on: sut)
//	}
//
//	func test_delete_hasNoSideEffectsOnDeletionError() throws {
////		let sut = try makeSUT()
////
////		assertThatDeleteHasNoSideEffectsOnDeletionError(on: sut)
//	}
//
//}
