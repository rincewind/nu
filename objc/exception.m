/*!
@file exception.m
@discussion  NuException
@copyright Copyright (c) 2007 Neon Design Technology, Inc.

Added by Peter Quade <pq@pqua.de>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License. 
*/

#import "nuinternals.h"
#import "exception.h"
#import "cell.h"

@implementation NuException

- (void) dealloc
{
    if (traceback) {
        [traceback release];
    }
    [super dealloc];
}

- (id)initWithName:(NSString *)name reason:(NSString *)reason userInfo:(NSDictionary *)userInfo
{
    self = [super initWithName:name reason:reason userInfo:userInfo];
    traceback = Nu__null;
    return self;
}

- (NuCell *) traceback {
    return traceback;
}


- (NuException *) addFunction:(NSString *)function linenumber:(NSUInteger )line
{
    return [self addFunction:function linenumber:line filename:@"n/a"];
}

- (NuException *) addFunction:(NSString *)function linenumber:(NSUInteger )line filename:(NSString *)filename
{
    NuCell* newcell = [[NuCell alloc] init];
    [newcell setCdr: traceback];
    traceback = newcell;
    [traceback setCar: [[NuTraceInfo alloc] initWithFunction: function linenumber: line filename: filename]];
    
    return self;
}

- (NSString *) stringValue
{
    return [self reason];
}


@end

@implementation NuTraceInfo


- (id)initWithFunction:(NSString *)funct linenumber:(NSUInteger)line filename:(NSString *)filen
{
    self = [super init];
    filename = [filen retain];
    linenumber = [[NSNumber numberWithUnsignedInteger: line] retain];
    function = [funct retain];
    return self;
}

- (void) dealloc
{
    [filename release];
    [linenumber release];
    [function release];
    [super dealloc];
}

- (NSString *) filename
    {return filename;}

- (NSNumber *) linenumber
{return linenumber;
}

- (NSString *) function
    {return function;}

@end