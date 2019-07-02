//
//  DBManager.swift
//  FMDBTut
//
//  Created by Nathan Hsu on 2019-07-01.
//  Copyright © 2019 Appcoda. All rights reserved.
//

import UIKit

class DBManager: NSObject {
    
    let field_MovieID = "movieID"
    let field_MovieTitle = "title"
    let field_MovieCategory = "category"
    let field_MovieYear = "year"
    let field_MovieURL = "movieURL"
    let field_MovieCoverURL = "coverURL"
    let field_MovieWatched = "watched"
    let field_MovieLikes = "likes"
    
    static let shared: DBManager = DBManager()
    
    let databaseFileName = "database.sqlite"
    var pathToDatabase: String!
    var database: FMDatabase!
    
    override init() {
        super.init()
        
        let documentsDirectory = (NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString) as String
        pathToDatabase = documentsDirectory.appending("/\(databaseFileName)")
    }
    
    func createDatabase() -> Bool {
        var created = false
        
        if !FileManager.default.fileExists(atPath: pathToDatabase) {
            database = FMDatabase(path: pathToDatabase!)
            
            if database != nil {
                // Open database
                if database.open() {
                    
                    let createMoviesTableQuery = """
                    create table movies (
                    \(field_MovieID) integer primary key autoincrement not null,
                    \(field_MovieTitle)
                    \(field_MovieCategory) text not null,
                    \(field_MovieYear) integer not null,
                    \(field_MovieURL) text,
                    \(field_MovieCoverURL) text not null,
                    \(field_MovieWatched) bool not null default 0,
                    \(field_MovieLikes) integer not null
                    )
                    """
                
                    
                    do {
                        try database.executeUpdate(createMoviesTableQuery, values: nil)
                        created = true
                    } catch {
                        print("Could not create table.")
                        print(error.localizedDescription)
                    }
                    
                    //At the end close the database.
                    database.close()
                    
                } else {
                    print("Could not open database")
                }
            }
            
        }
        
        return created
    }
    func openDatabase() -> Bool {
        if database == nil {
            if FileManager.default.fileExists(atPath: pathToDatabase) {
                database = FMDatabase(path: pathToDatabase)
            }
        }
        
        if database != nil {
            if database.open() {
                return true
            }
        }
        
        return false
    }
    func insertMovieData() {
        // Open the database.
        if openDatabase() {
            // 1 locate movies.tsv file and load contents into String object
            if let pathToMoviesFile = Bundle.main.path(forResource: "movies", ofType: "tsv") {
                do {
                    let moviesFileContents = try String(contentsOfFile: pathToMoviesFile)
                    
                    // 2 break down contents into separate movies
                    let moviesData = moviesFileContents.components(separatedBy: "\r\n")
                    
                    // 3 break down movies into different data pieces and form a query
                    var query = ""
                    
                    for movie in moviesData {
                        let movieParts = movie.components(separatedBy: "\t")
                        if movieParts.count == 5 {
                            
                            let movieTitle = movieParts[0]
                            let movieCategory = movieParts[1]
                            let movieYear = movieParts[2]
                            let movieURL = movieParts[3]
                            let movieCoverURL = movieParts[4]
                            
                            query += """
                                insert into movies (
                                    \(field_MovieID),
                                    \(field_MovieTitle),
                                    \(field_MovieCategory),
                                    \(field_MovieYear),
                                    \(field_MovieURL),
                                    \(field_MovieCoverURL),
                                    \(field_MovieWatched),
                                    \(field_MovieLikes)
                                )
                                values (
                                    null,
                                    '\(movieTitle)',
                                    '\(movieCategory)',
                                    \(movieYear),
                                    '\(movieURL)',
                                    '\(movieCoverURL)',
                                    0,
                                    0
                                )
                                ;
                            """
                        }
                    }
                    
                    // 4 execute the newly formed query
                    if !database.executeStatements(query) {
                        print("Failed to insert initial data into the database.")
                        print(database.lastError(), database.lastErrorMessage())
                    }
                    
                } catch {
                    print(error.localizedDescription)
                }
            }
            
            database.close()
        }
    }
    func loadMovies() -> [MovieInfo]! {
        var movies: [MovieInfo]!
        
        
        
        if openDatabase() {
            
            // Step 1: Create query and try to execute it to get FMResultSet object back
            
            // Step 2: Convert and process FMResults to objects and insert into our movies array
            func process(_ results: FMResultSet) {
                while results.next() {
                
                    let movie = MovieInfo(movieID: Int(results.int(forColumn: field_MovieID)),
                                          title: results.string(forColumn: field_MovieTitle),
                                          category: results.string(forColumn: field_MovieCategory),
                                          year: Int(results.int(forColumn: field_MovieYear)),
                                          movieURL: results.string(forColumn: field_MovieURL),
                                          coverURL: results.string(forColumn: field_MovieCoverURL),
                                          watched: results.bool(forColumn: field_MovieWatched),
                                          likes: Int(results.int(forColumn: field_MovieLikes)))
                    if movies == nil {
                        movies = []
                    }
                    movies.append(movie)
                }
            }
            
            // Step 1:
            // Example 1:
            let query = "select * from movies order by \(field_MovieYear) asc"
            do {
                let results = try database.executeQuery(query, values: nil)
                process(results)
            } catch {
                print(error.localizedDescription)
            }
            
//            // Example 2:
//            let query = "select * from movies where \(field_MovieCategory)=? order by \(field_MovieYear)"
//            do {
//                let results = try database.executeQuery(query, values: ["Crime"])
//                process(results)
//            } catch {
//                print(error.localizedDescription)
//            }
            
//            // Example 3:
//            let query = "select * from movies where \(field_MovieCategory)=? and \(field_MovieYear)>? order by \(field_MovieID) desc"
//            do {
//                let results = try database.executeQuery(query, values: ["Crime", 1990])
//                // Step 2: Loop throught the results and convert into MovieInfo objects and store in movies array.
//                process(results)
//            } catch {
//                print(error.localizedDescription)
//            }
            
            database.close()
            
        }
        
        return movies
    }
    func loadMovie(withID ID: Int, completionHandler: (_ movieInfo: MovieInfo?) -> Void) {
        var movieInfo: MovieInfo!
        if openDatabase() {
            let query = "select * from movies where movieID=?"
            do {
                let results = try database.executeQuery(query, values: [ID])
                if results.next() {
                    movieInfo = MovieInfo(movieID: Int(results.int(forColumn: field_MovieID)),
                                          title: results.string(forColumn: field_MovieTitle),
                                          category: results.string(forColumn: field_MovieCategory),
                                          year: Int(results.int(forColumn: field_MovieYear)),
                                          movieURL: results.string(forColumn: field_MovieURL),
                                          coverURL: results.string(forColumn: field_MovieCoverURL),
                                          watched: results.bool(forColumn: field_MovieWatched),
                                          likes: Int(results.int(forColumn: field_MovieLikes)))
                } else {
                    print(database.lastError())
                }
            } catch {
                print(error.localizedDescription)
            }
            database.close()
        }
        completionHandler(movieInfo)
    }
    func updateMovie(withID ID: Int, watched: Bool, likes: Int) {
        if openDatabase() {
            let query = "update movies set \(field_MovieWatched)=?, \(field_MovieLikes)=? where \(field_MovieID)=?"
            do {
                try database.executeUpdate(query, values: [watched, likes, ID])
            } catch {
                print(error.localizedDescription)
            }
            database.close()
        }
    }
    func deleteMovie(withID ID: Int) -> Bool {
        var deleted = false
        
        if openDatabase() {
            let query = "delete from movies where \(field_MovieID)=?"
            do {
                try database.executeUpdate(query, values: [ID])
                deleted = true
            } catch {
                print(error.localizedDescription)
            }
            database.close()
        }
        return deleted
    }
}
