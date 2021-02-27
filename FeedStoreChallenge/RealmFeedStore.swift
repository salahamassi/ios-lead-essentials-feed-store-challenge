//
//  RealmFeedStore.swift
//  FeedStoreChallenge
//
//  Created by Salah Amassi on 27/02/2021.
//  Copyright © 2021 Essential Developer. All rights reserved.
//

import Foundation
import RealmSwift

public class RealmFeedStore: FeedStore {
	
	private let storeURL: URL?
	
	public init(storeURL: URL?) {
		self.storeURL = storeURL
	}
	
	public func retrieve(completion: @escaping RetrievalCompletion) {
		do {
			let realm = try getRealm()
			if let cache = realm.objects(Cache.self).last {
				completion(.found(feed: cache.feed, timestamp: cache.timestamp))
			} else {
				completion(.empty)
			}
		} catch Realm.Error.fileNotFound, Realm.Error.filePermissionDenied {
			completion(.empty)
		} catch {
			completion(.failure(error))
		}
	}
	
	public func insert(_ feed: [LocalFeedImage], timestamp: Date, completion: @escaping InsertionCompletion) {
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
	
	public func deleteCachedFeed(completion: @escaping DeletionCompletion) {
		do {
			let realm = try getRealm()
			try realm.write {
				realm.deleteAll()
			}
			completion(nil)
		} catch {
			completion(error)
		}
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

private extension Array where Element == LocalFeedImage {
	
	func toRealmList() -> List<RealmFeedImage> {
		let list = List<RealmFeedImage> ()
		forEach { list.append(.init($0)) }
		return list
	}
}

private extension List where Element == RealmFeedImage {
	
	func toArray() -> [LocalFeedImage] {
		var array = [LocalFeedImage]()
		for item in self {
			guard let local = item.local else { continue }
			array.append(local)
		}
		return array
	}
}
