//
//  BaseDb.swift
//  ios
//
//  Copyright © 2018 Tinode. All rights reserved.
//

import Foundation
import SQLite

public class BaseDb {
    // Current database schema version. Increase on schema changes.
    public static let kSchemaVersion: Int32 = 100

    // Onject statuses.
    // Status undefined/not set.
    public static let kStatusUndefined = 0
    // Object is not ready to be sent to the server.
    public static let kStatusDraft = 1
    // Object is ready but not yet sent to the server.
    public static let kStatusQueued = 2
    // Object is in the process of being sent to the server.
    public static let kStatusSending = 3
    // Object is received by the server.
    public static let kStatusSynced = 4
    // Meta-status: object should be visible in the UI.
    public static let kStatusVisible = 4
    // Object is hard-deleted.
    public static let kStatusDeletedHard = 5
    // Object is soft-deleted.
    public static let kStatusDeletedSoft = 6
    // Object is rejected by the server.
    public static let kStatusRejected = 7

    
    public static var `default`: BaseDb? = nil
    private let kDatabaseName = "basedb.sqlite3"
    var db: SQLite.Connection?
    private let pathToDatabase: String
    var sqlStore: SqlStore?
    var topicDb: TopicDb? = nil
    var accountDb: AccountDb? = nil
    var subscriberDb: SubscriberDb? = nil
    var userDb: UserDb? = nil
    var messageDb: MessageDb? = nil
    var account: StoredAccount? = nil
    var isReady: Bool { get { return self.account != nil } }
    init() {
        var documentsDirectory = (NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString) as String
        if documentsDirectory.last! != "/" {
            documentsDirectory.append("/")
        }
        self.pathToDatabase = documentsDirectory.appending("database.sqlite")
        
        do {
            self.db = try SQLite.Connection(self.pathToDatabase)
            if self.db?.schemaVersion != BaseDb.kSchemaVersion {
                // Delete database if schema has changed.
                self.onDestroy()
            }
        } catch {
            print(error.localizedDescription)
        }
        assert(self.db != nil)
        
        self.sqlStore = SqlStore(dbh: self)
    }
    private func onCreate() {
        self.accountDb = AccountDb(self.db!)
        self.accountDb!.createTable()
        self.userDb = UserDb(self.db!)
        self.userDb!.createTable()
        self.topicDb = TopicDb(self.db!)
        self.topicDb!.createTable()
        self.subscriberDb = SubscriberDb(self.db!)
        self.subscriberDb!.createTable()
        self.messageDb = MessageDb(self.db!)
        self.messageDb!.createTable()
        self.account = self.accountDb!.getActiveAccount()

        self.db?.schemaVersion = BaseDb.kSchemaVersion
    }
    private func onDestroy() {
        self.messageDb?.destroyTable()
        self.subscriberDb?.destroyTable()
        self.topicDb?.destroyTable()
        self.userDb?.destroyTable()
        self.accountDb?.destroyTable()
    }
    static func getInstance() -> BaseDb {
        if let instance = BaseDb.default {
            return instance
        }
        let instance = BaseDb()
        BaseDb.default = instance
        instance.onCreate()
        return instance
    }
    func isMe(uid: String?) -> Bool {
        guard let uid = uid, let acctUid = BaseDb.getInstance().uid else { return false }
        return uid == acctUid
    }
    var uid: String? {
        get { return self.account?.uid }
    }
    func setUid(uid: String?) {
        guard let uid = uid else {
            self.account = nil
            return
        }
        do {
            if self.account != nil {
                try self.accountDb?.deactivateAll()
            }
            self.account = self.accountDb?.addOrActivateAccount(for: uid)
        } catch {
            print("setUid failed \(error)")
            self.account = nil
        }
    }
    func logout() {
        _ = try? self.accountDb?.deactivateAll()
        self.setUid(uid: nil)
    }
}

// Database schema versioning.
extension Connection {
    public var schemaVersion: Int32 {
        get { return Int32(try! scalar("PRAGMA schema_version") as! Int64)}
        set { try! run("PRAGMA schema_version = \(newValue)") }
    }
}
