//
//  Licenses.swift
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

/// Database's Licenses table, in charge of keeping tracks of the
/// licenses attributed to each books and the associated rights.
class Licenses {
    /// Table.
    let licenses = Table("Licenses")
    /// Fields.
    let id = Expression<String>("id")
    let printsLeft = Expression<Int?>("printsLeft")
    let copiesLeft = Expression<Int?>("copiesLeft")
    let provider = Expression<String>("provider")
    let issued = Expression<Date>("issued")
    let updated = Expression<Date?>("updated")
    let end = Expression<Date?>("end")
    let state = Expression<String?>("state")
    
    let registered = Expression<Bool>("registered")
    
    let localFileURL = Expression<String?>("localFileURL")
    let localFileUpdated = Expression<Date?>("localFileUpdated")

    init(_ connection: Connection) {
        
        _ = try? connection.run(licenses.create(temporary: false, ifNotExists: true) { t in
            t.column(id, unique: true)
            t.column(printsLeft)
            t.column(copiesLeft)
            t.column(provider)
            t.column(issued)
            t.column(updated)
            t.column(end)
            t.column(state)
        })
        
        if 0 == connection.userVersion {
            _ = try? connection.run(licenses.addColumn(registered, defaultValue: false))
            connection.userVersion = 1
        }
        if 1 == connection.userVersion {
            _ = try? connection.run(licenses.addColumn(localFileURL))
            _ = try? connection.run(licenses.addColumn(localFileUpdated))
            connection.userVersion = 2
        }
    }

    internal func dateOfLastUpdate(forLicenseWith id: String) -> Date? {
        let db = LCPDatabase.shared.connection
        let query = licenses.filter(self.id == id).select(updated).order(updated.desc)

        do {
            for result in try db.prepare(query) {
                do {
                    return try result.get(updated)
                } catch {
                    return nil
                }
            }
        } catch {
            return nil
        }
        return nil
    }

    internal func updateState(forLicenseWith id: String, to state: String) throws {
        let db = LCPDatabase.shared.connection
        let license = licenses.filter(self.id == id)

        // Check if empty.
        guard try db.scalar(license.count) > 0 else {
            throw LcpError.licenseNotFound
        }
        try db.run(license.update(self.state <- state))
    }
    
    internal func register(forLicenseWith id: String) throws {
        let db = LCPDatabase.shared.connection
        let license = licenses.filter(self.id == id)
        
        // Check if empty.
        guard try db.scalar(license.count) > 0 else {
            throw LcpError.licenseNotFound
        }
        try db.run(license.update(self.registered <- true))
    }

    /// Check if the table already contains an entry for the given ID.
    ///
    /// - Parameter id: The ID to check for.
    /// - Returns: A boolean indicating the result of the search, true if found.
    /// - Throws: .
    internal func existingLicense(with id: String) throws -> Bool {
        let db = LCPDatabase.shared.connection
        // Check if empty.
        guard try db.scalar(licenses.count) > 0 else {
            return false
        }
        let query = licenses.filter(self.id == id)
        let count = try db.scalar(query.count)

        return count == 1
    }
    
    internal func localFileExisting(for licenseID: String) throws -> Bool {
        let db = LCPDatabase.shared.connection
        // Check if empty.
        guard try db.scalar(licenses.count) > 0 else {
            return false
        }
        let query = licenses.filter(self.id == licenseID && self.localFileURL != nil)
        let count = try db.scalar(query.count)
        
        return count == 1
    }
    
    internal func updateLocalFile(for licenseID: String, localURL: String, updatedAt: Date) throws -> Void {
        
        let db = LCPDatabase.shared.connection
        let license = licenses.filter(self.id == id)
        
        // Check if empty.
        guard try db.scalar(license.count) > 0 else {
            throw LcpError.licenseNotFound
        }
        
        try db.run(license.update(self.localFileURL <- localURL,
                                  self.localFileUpdated <- updatedAt))
    }
    
    internal func deleteLocalFile(for licenseID: String) throws -> Void {
        
        let db = LCPDatabase.shared.connection
        let license = licenses.filter(self.id == id)
        
        // Check if empty.
        guard try db.scalar(license.count) > 0 else {
            throw LcpError.licenseNotFound
        }
        
        try db.run(license.update(self.localFileURL <- nil,
                                  self.localFileUpdated <- nil))
    }
    
    internal func deleteData(for licenseID: String) throws -> Void {
        
        let db = LCPDatabase.shared.connection
        let license = licenses.filter(self.id == id)
        
        // Check if empty.
        guard try db.scalar(license.count) > 0 else {
            throw LcpError.licenseNotFound
        }
        
        try db.run(license.delete())
    }
    
    /// Check if the table already contains an entry for the given ID which is registered
    ///
    /// - Parameter id: The ID to check for.
    /// - Returns: A boolean indicating the result of the search, true if found.
    /// - Throws: .
    internal func checkRegister(with id: String) throws -> Bool {
        let db = LCPDatabase.shared.connection
        // Check if empty.
        guard try db.scalar(licenses.count) > 0 else {
            return false
        }
        let query = licenses.filter(self.id == id && self.registered == true)
        let count = try db.scalar(query.count)
        
        return count == 1
    }

    /// Add a registered license to the database.
    ///
    /// - Parameters:
    ///   - license: <#license description#>
    ///   - status: <#status description#>
    /// - Throws: <#throws value description#>
    internal func insert(_ license: LicenseDocument, with status: StatusDocument.Status?) throws {
        let db = LCPDatabase.shared.connection

        let insertQuery = licenses.insert(
            id <- license.id,
            printsLeft <- license.rights.print,
            copiesLeft <- license.rights.copy,
            provider <- license.provider.absoluteString,
            issued <- license.issued,
            updated <- license.updated,
            end <- license.rights.end,
            state <- status?.rawValue ?? nil,
            registered <- false
        )
        
        try db.run(insertQuery)
    }
    
}
