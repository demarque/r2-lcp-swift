//
//  Transactions.swift
//  readium-lcp-swift
//
//  Created by Alexandre Camilleri on 10/2/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import SQLite
import R2Shared


/// Database's TransactionsTable , in charge of keeping tracks of the previous license checking.
class Transactions: Loggable {
    /// Table.
    let transactions = Table("Transactions")
    /// Fields.
    let licenseId = Expression<String>("licenseId")
    let origin = Expression<String>("origin")
    let userId = Expression<String?>("userId")
    let passphrase = Expression<String>("passphrase") // hashed.
    
    init(_ connection: Connection)  {
        do {
            try connection.run(transactions.create(temporary: false, ifNotExists: true) { t in
                t.column(licenseId)
                t.column(origin)
                t.column(userId)
                t.column(passphrase)
            })
        } catch {
            log(.error, error)
        }
    }

}


extension Transactions: PassphrasesRepository {
    
    func all() -> [String] {
        let db = Database.shared.connection
        let query = transactions.select(passphrase)
        do {
            return try db.prepare(query).compactMap({ try $0.get(passphrase) })
        } catch {
            log(.error, error)
            return []
        }
    }
    
    func passphrase(forLicenseId licenseId: String) -> String? {
        do {
            let db = Database.shared.connection
            let query = transactions.select(passphrase).filter(self.licenseId == licenseId)
    
            for row in try db.prepare(query) {
                return try row.get(passphrase)
            }
        } catch {
            log(.error, error)
        }
        
        return nil
    }
    
    func passphrases(forUserId userId: String) -> [String] {
        let db = Database.shared.connection
        let query = transactions.select(passphrase).filter(self.userId == userId)
        do {
            return try db.prepare(query).compactMap({ try $0.get(passphrase) })
        } catch {
            log(.error, error)
            return []
        }
    }
    
    func addPassphrase(_ passphraseHash: String, forLicenseId licenseId: String?, provider: String?, userId: String?) -> Bool {
        let db = Database.shared.connection

        let insertQuery = transactions.insert(
            self.licenseId <- licenseId ?? "",
            self.origin <- provider ?? "",
            self.userId <- userId,
            self.passphrase <- passphraseHash
        )
        do {
            try db.run(insertQuery)
            return true
        } catch {
            log(.error, error)
            return false
        }
    }
    
}
