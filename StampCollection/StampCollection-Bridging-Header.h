//
//  StampCollection-Bridging-Header.h
//  StampCollection
//
//  Created by Michael L Mehr on 4/9/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

#ifndef StampCollection_StampCollection_Bridging_Header_h
#define StampCollection_StampCollection_Bridging_Header_h

/*
 This was the easiest to import. I just stole the .h and .m file and put them into my project.
 Source: https://github.com/davedelong/CHCSVParser
 */
#import "CHCSVParser.h"

/*
 Source: https://github.com/ZipArchive/ZipArchive
 Requirements: Add the SSZipArchive.h/.m and the minizip project, then add libz.dylib to the target.
 I had various problems when importing the SSZipArchive files. Had to experiment with various locations, and what finally worked may not be ideal in terms of files in the project. The libz.dylib file ended up outside  (I just recently moved it into the right group.) I tried to add everything to SupportingFiles, but there are many other files that got into the project directories, hopefully not referenced here in the project. So it goes.
 */
#import "SSZipArchive.h"

/*
 Source: https://github.com/tumblr/TMCache
 I copied the files manually after cloning the project. Then I put the selection into subfolder (TMCache) but left them in the main folder physically to simplify the reference here.
 */
#import "TMCache.h"

#endif
