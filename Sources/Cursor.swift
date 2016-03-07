//
//  Cursor.swift
//  swiftMongoDB
//
//  Created by Dan Appel on 8/20/15.
//  Copyright © 2015 Dan Appel. All rights reserved.
//

import CMongoC
import BinaryJSON

public struct Cursor: GeneratorType, SequenceType {

    public typealias Options = (queryFlag: QueryFlag, skip: Int, limit: Int, batchSize: Int)

    public enum Operation {
        case Find
    }

    private let cursor: UnsafeCursor

    init(pointer: _mongoc_cursor) {
        self.cursor = UnsafeCursor(cursor: pointer)
    }

    public init(collection: Collection, operation: Operation, query: BSON.Document, options: Options) throws {

        guard let query = BSON.unsafePointerFromDocument(query) else {
            throw MongoError.CorruptDocument
        }

        let pointer: _mongoc_cursor

        switch operation {
        case .Find:
            pointer = mongoc_collection_find(
                collection.pointer,
                options.queryFlag.rawFlag,
                options.skip.UInt32Value,
                options.limit.UInt32Value,
                options.batchSize.UInt32Value,
                query, nil, nil
            )
        }

        self.init(pointer: pointer)
    }

    var lastError: MongoError {
        var error = bson_error_t()
        mongoc_cursor_error(cursor.pointer, &error)
        return error.error
    }

    public func next() -> BSON.Document? {
        guard let bson = cursor.next() else {
            return nil
        }

        return BSON.documentFromUnsafePointer(bson)
    }

    public func nextDocument() throws -> BSON.Document? {
        guard let next = next() else {
            return nil
        }

        if lastError.isError {
            throw lastError
        }

        return next
    }

    public func all() throws -> [BSON.Document] {

        var documents: [BSON.Document] = []

        while let document = try nextDocument() {
            documents.append(document)
        }

        return documents
    }
}

private final class UnsafeCursor:  GeneratorType {
    let pointer: _mongoc_cursor

    init(cursor: _mongoc_cursor) {
        self.pointer = cursor
    }

    deinit {
        mongoc_cursor_destroy(pointer)
    }

    func next() -> UnsafePointer<bson_t>? {
        var buffer = UnsafePointer<bson_t>()

        let isOk = mongoc_cursor_next(self.pointer, &buffer)

        if isOk && buffer != nil {
            let mutableCopy = bson_copy(buffer)
            let copy = UnsafePointer<bson_t>(mutableCopy)
            return copy
        }

        return nil
    }
}
