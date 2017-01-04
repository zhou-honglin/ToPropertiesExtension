//
//  SourceEditorCommand.m
//  modeltor
//
//  Created by zhou iMac on 12/28/16.
//  Copyright © 2016 zhou iMac. All rights reserved.
//

#import "SourceEditorCommand.h"

static inline NSString* GetNSType(id obj){
    NSString *defaultType = @"NSString*";
    if (!obj) return defaultType;
    if ([obj isKindOfClass:[NSString class]]) return defaultType;
    if ([obj isKindOfClass:[NSNumber class]]){
        NSNumber *num = obj;
        if(strcmp([num objCType], @encode(BOOL)) == 0)
            return @"BOOL";
        else if(strcmp([num objCType], @encode(float)) == 0)
            return @"float";
        else if(strcmp([num objCType], @encode(double)) == 0)
            return @"double";
        else
            return @"NSInteger";
    }
    return defaultType;
}
static inline NSString *GetQualifier(NSString* type){
    if ([type isEqualToString:@"NSString*"]) return @"copy";
    if ([@[@"BOOL",@"float",@"double",@"NSInteger"] containsObject:type]) return  @"assign";
    return  @"strong";
    
}

@implementation SourceEditorCommand

- (void)performCommandWithInvocation:(XCSourceEditorCommandInvocation *)invocation completionHandler:(void (^)(NSError * _Nullable nilOrError))completionHandler
{
    // Implement your command here, invoking the completion handler when done. Pass it nil on success, and an NSError on failure.
    NSMutableArray<XCSourceTextRange *> *selections = invocation.buffer.selections;
    NSMutableArray<NSString *> *lines = invocation.buffer.lines;
    
    
    XCSourceTextRange *range = selections[0];
    NSUInteger index = range.start.line;
    NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
    //a insert point
    if (range.start.line == range.end.line && range.start.column == range.end.column) {
        completionHandler(nil);
        return;
    }
    
    NSMutableString *mutableString = [NSMutableString string];
    for (XCSourceTextRange *selection in selections) {
        NSInteger startLine = selection.start.line;
        NSInteger endLine =  selection.end.line;
        NSInteger startColumn = selection.start.column;
        NSInteger endColumn = selection.end.column;
        
        
        NSMutableString *selectString =[NSMutableString string];
        if (startLine == endLine) { // sigle line
            [indexes addIndex:startLine];
            NSRange range = NSMakeRange(startColumn, (endColumn - startColumn));
            NSString *str = [lines[startLine] substringWithRange:range];
            [selectString appendString:str];
        }
        else{//muti lines
            for (NSInteger i = startLine; i <= endLine; i++) {
                [indexes addIndex:i];
                NSString *line = lines[i];
                if (i == startLine) {
                    line = [line substringFromIndex:startColumn];
                }else if (i == endLine) {
                    line = [line substringToIndex:endColumn];
                }
                [selectString appendString:line];
            }
        }
        
        [mutableString appendString:selectString];
    }
    NSString *json = [mutableString stringByReplacingOccurrencesOfString:@"\\s"
                                                              withString:@""
                                                                 options:NSRegularExpressionSearch
                                                                   range:NSMakeRange(0, [mutableString length])];
    NSError *error;
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
    if (error) {
        completionHandler(error);
        return;
    }
    __block NSMutableArray * properties = [[NSMutableArray alloc] init];
    [dict enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        NSString *type = GetNSType(obj);
        NSDictionary *property = @{@"key":key,
                                   @"value":obj,
                                   @"type":type,
                                   @"qualifier":GetQualifier(type)
                                   };
        [properties addObject:property];
    }];
    
    NSMutableArray *newLines = [[NSMutableArray alloc] init];
    for (NSDictionary *property in properties) {
        NSString *newLine = [NSString stringWithFormat:@"@property (nonatomic, %@) %@ %@;\n",property[@"qualifier"],property[@"type"],property[@"key"]];
        [newLines addObject:newLine];
    }
    
    [lines removeObjectsAtIndexes:indexes];
    [lines insertObjects:newLines atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(index, newLines.count)]];
    XCSourceTextRange *newSelection = [[XCSourceTextRange alloc] init];
    newSelection.start = XCSourceTextPositionMake(index, 0);
    newSelection.end = XCSourceTextPositionMake(index + newLines.count, 0);
    [invocation.buffer.selections setArray:@[newSelection]];
    
    completionHandler(nil);
}

@end




