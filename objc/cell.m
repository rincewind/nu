/*!
@file cell.m
@description Nu cells.
@copyright Copyright (c) 2007 Neon Design Technology, Inc.

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
#import "cell.h"
#import "symbol.h"
#import "extensions.h"
#import "operator.h"
#import "block.h"
#import "dtrace.h"
#import "object.h"
#import "objc_runtime.h"

@class NuException;
@implementation NuCell

+ (id) cellWithCar:(id)car cdr:(id)cdr
{
    NuCell *cell = [[self alloc] init];
    [cell setCar:car];
    [cell setCdr:cdr];
    return [cell autorelease];
}

- (id) init
{
    [super init];
    car = Nu__null;
    cdr = Nu__null;
    file = -1;
    line = -1;
    return self;
}

- (void) dealloc
{
    [car release];
    [cdr release];
    [super dealloc];
}

- (bool) atom {return false;}

- (id) car {return car;}

- (id) cdr {return cdr;}

- (void) setCar:(id) c
{
    [c retain];
    [car release];
    car = c;
}

- (void) setCdr:(id) c
{
    [c retain];
    [cdr release];
    cdr = c;
}

- (BOOL) isEqual:(id) other
{
    if (nu_objectIsKindOfClass(other, [NuCell class])
    && [[self car] isEqual:[other car]] && [[self cdr] isEqual:[other cdr]]) {
        return YES;
    }
    else {
        return NO;
    }
}

- (id) first
{
    return car;
}

- (id) second
{
    return [cdr car];
}

- (id) third
{
    return [[cdr cdr] car];
}

- (id) fourth
{
    return [[[cdr cdr]  cdr] car];
}

- (id) fifth
{
    return [[[[cdr cdr]  cdr]  cdr] car];
}

- (id) nth:(int) n
{
    if (n == 1)
        return car;
    id cursor = cdr;
    int i;
    for (i = 2; i < n; i++) {
        cursor = [cursor cdr];
        if (cursor == Nu__null) return nil;
    }
    return [cursor car];
}

- (id) objectAtIndex:(int) n
{
    if (n < 0)
        return nil;
    else if (n == 0)
        return car;
    id cursor = cdr;
    for (int i = 1; i < n; i++) {
        cursor = [cursor cdr];
        if (cursor == Nu__null) return nil;
    }
    return [cursor car];
}

// When an unknown message is received by a cell, treat it as a call to objectAtIndex:
- (id) handleUnknownMessage:(NuCell *) method withContext:(NSMutableDictionary *) context
{
    id m = [[method car] evalWithContext:context];
    if ([m isKindOfClass:[NSNumber class]]) {
        int mm = [m intValue];
        if (mm < 0) {
            // if the index is negative, index from the end of the array
            mm += [self length];
        }
        return [self objectAtIndex:mm];
    }
    else {
        return [super handleUnknownMessage:method withContext:context];
    }
}

- (id) lastObject
{
    id cursor = self;
    while ([cursor cdr] != Nu__null) {
        cursor = [cursor cdr];
    }
    return [cursor car];
}

- (NSMutableString *) stringValue
{
    NuCell *cell = self;
    NSMutableString *result = [NSMutableString stringWithString:@"("];
    bool first = true;
    while (IS_NOT_NULL(cell)) {
        if (first)
            first = false;
        else
            [result appendString:@" "];
        id mycar = [cell car];
        if (nu_objectIsKindOfClass(mycar, [NuCell class])) {
            [result appendString:[mycar stringValue]];
        }
        else if (mycar && (mycar != Nu__null)) {
            [result appendString:[mycar description]];
        }
        else {
            [result appendString:@"()"];
        }
        cell = [cell cdr];
        // check for dotted pairs
        if (IS_NOT_NULL(cell) && !nu_objectIsKindOfClass(cell, [NuCell class])) {
            [result appendString:@" . "];
            [result appendString:[cell description]];
            break;
        }
    }
    [result appendString:@")"];
    return result;
}

extern char *nu_parsedFilename(int i);

- (id) evalWithContext:(NSMutableDictionary *)context
{
    id value = nil;
    @try {

    value = [car evalWithContext:context];

    #ifdef DARWIN
    if (NU_LIST_EVAL_BEGIN_ENABLED()) {
        if ((self->line != -1) && (self->file != -1)) {
            NU_LIST_EVAL_BEGIN(nu_parsedFilename(self->file), self->line);
        }
        else {
            NU_LIST_EVAL_BEGIN("", 0);
        }
    }
    #endif
    id result = [value evalWithArguments:cdr context:context];

    #ifdef DARWIN
    if (NU_LIST_EVAL_END_ENABLED()) {
        if ((self->line != -1) && (self->file != -1)) {
            NU_LIST_EVAL_END(nu_parsedFilename(self->file), self->line);
        }
        else {
            NU_LIST_EVAL_END("", 0);
        }
    }
    #endif
    return result;
    } @catch (NuException* nuexc) {
        @throw [self addToException:nuexc value:value];
    } @catch (NSException* exc) {
        NuException* nuexc = [[NuException alloc] initWithName: [exc name] reason: [exc reason] userInfo: [exc userInfo]];
        @throw [self addToException:nuexc value:value];
    }
}

- (NuException *) addToException:(NuException *)exc value:(id)value {
    NSString* nsfname;
    NSString* nsfunct;
    
    char* fname = nu_parsedFilename(self->file);
    
    if (value) {
        nsfunct = [value description];
    } else {
        nsfunct = @"n/a";
    }
    
    if (fname) {
        nsfname =  [NSString stringWithCString: fname encoding: NSUTF8StringEncoding];
        [exc addFunction: nsfunct linenumber: [self line] filename: nsfname];

    } else {
        [exc addFunction: nsfunct linenumber: [self line]];        
    }
}

- (id) each:(NuBlock *) block
{
    if (nu_objectIsKindOfClass(block, [NuBlock class])) {
        id args = [[NuCell alloc] init];
        id cursor = self;
        while (cursor && (cursor != Nu__null)) {
            [args setCar:[cursor car]];
            [block evalWithArguments:args context:Nu__null];
            cursor = [cursor cdr];
        }
        [args release];
    }
    return self;
}

- (id) eachPair:(NuBlock *) block
{
    if (nu_objectIsKindOfClass(block, [NuBlock class])) {
        id args = [[NuCell alloc] init];
        [args setCdr:[[[NuCell alloc] init] autorelease]];
        id cursor = self;
        while (cursor && (cursor != Nu__null)) {
            [args setCar:[cursor car]];
            [[args cdr] setCar:[[cursor cdr] car]];
            [block evalWithArguments:args context:Nu__null];
            cursor = [[cursor cdr] cdr];
        }
        [args release];
    }
    return self;
}

- (id) eachWithIndex:(NuBlock *) block
{
    if (nu_objectIsKindOfClass(block, [NuBlock class])) {
        id args = [[NuCell alloc] init];
        [args setCdr:[[NuCell alloc] init]];
        id cursor = self;
        int i = 0;
        while (cursor && (cursor != Nu__null)) {
            [args setCar:[cursor car]];
            [[args cdr] setCar:[NSNumber numberWithInt:i]];
            [block evalWithArguments:args context:Nu__null];
            cursor = [cursor cdr];
            i++;
        }
        [args release];
    }
    return self;
}

- (id) select:(NuBlock *) block
{
    NuCell *parent = [[NuCell alloc] init];
    if (nu_objectIsKindOfClass(block, [NuBlock class])) {
        id args = [[NuCell alloc] init];
        id cursor = self;
        id resultCursor = parent;
        while (cursor && (cursor != Nu__null)) {
            [args setCar:[cursor car]];
            id result = [block evalWithArguments:args context:Nu__null];
            if (result && (result != Nu__null)) {
                [resultCursor setCdr:[NuCell cellWithCar:[cursor car] cdr:[resultCursor cdr]]];
                resultCursor = [resultCursor cdr];
            }
            cursor = [cursor cdr];
        }
        [args release];
    }
    else
        return Nu__null;
    NuCell *selected = [parent cdr];
    [parent release];
    return selected;
}

- (id) find:(NuBlock *) block
{
    if (nu_objectIsKindOfClass(block, [NuBlock class])) {
        id args = [[NuCell alloc] init];
        id cursor = self;
        while (cursor && (cursor != Nu__null)) {
            [args setCar:[cursor car]];
            id result = [block evalWithArguments:args context:Nu__null];
            if (result && (result != Nu__null)) {
                [args release];
                return [cursor car];
            }
            cursor = [cursor cdr];
        }
        [args release];
    }
    return Nu__null;
}

- (id) map:(NuBlock *) block
{
    NuCell *parent = [[NuCell alloc] init];
    if (nu_objectIsKindOfClass(block, [NuBlock class])) {
        id args = [[NuCell alloc] init];
        id cursor = self;
        id resultCursor = parent;
        while (cursor && (cursor != Nu__null)) {
            [args setCar:[cursor car]];
            id result = [block evalWithArguments:args context:Nu__null];
            [resultCursor setCdr:[NuCell cellWithCar:result cdr:[resultCursor cdr]]];
            cursor = [cursor cdr];
            resultCursor = [resultCursor cdr];
        }
        [args release];
    }
    else
        return Nu__null;
    NuCell *result = [parent cdr];
    [parent release];
    return result;
}

- (id) reduce:(NuBlock *) block from:(id) initial
{
    id result = initial;
    if (nu_objectIsKindOfClass(block, [NuBlock class])) {
        id args = [[NuCell alloc] init];
        [args setCdr:[[NuCell alloc] init]];
        id cursor = self;
        while (cursor && (cursor != Nu__null)) {
            [args setCar:result];
            [[args cdr] setCar:[cursor car]];
            result = [block evalWithArguments:args context:Nu__null];
            cursor = [cursor cdr];
        }
        [[args cdr] release];
        [args release];
    }
    return result;
}

- (int) length
{
    int count = 0;
    id cursor = self;
    while (cursor && (cursor != Nu__null)) {
        cursor = [cursor cdr];
        count++;
    }
    return count;
}

- (id) comments {return nil;}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:car];
    [coder encodeObject:cdr];
}

- (id) initWithCoder:(NSCoder *)coder
{
    [super init];
    car = [[coder decodeObject] retain];
    cdr = [[coder decodeObject] retain];
    return self;
}

- (void) setFile:(int) f line:(int) l
{
    file = f;
    line = l;
}

- (int) file {return file;}
- (int) line {return line;}
@end

@implementation NuCellWithComments

- (id) comments {return comments;}

- (void) setComments:(id) c
{
    [c retain];
    [comments release];
    comments = c;
}

@end
